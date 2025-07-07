import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayV2HTTPEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayV2HTTPResponse;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.http.HttpHeaders;
import java.time.Duration;
import java.util.*;
import java.util.zip.GZIPOutputStream;

public class Handler implements RequestHandler<APIGatewayV2HTTPEvent, APIGatewayV2HTTPResponse> {

    private static final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(2))
            .build();

    static {
        org.traccar.Main.run("traccar.xml");
    }

    @Override
    public APIGatewayV2HTTPResponse handleRequest(APIGatewayV2HTTPEvent event, Context context) {
        String method = Optional.ofNullable(event.getRequestContext())
                .map(APIGatewayV2HTTPEvent.RequestContext::getHttp)
                .map(APIGatewayV2HTTPEvent.RequestContext.Http::getMethod)
                .orElse("GET");

        String path = Optional.ofNullable(event.getRawPath()).orElse("/");
        String query = Optional.ofNullable(event.getRawQueryString()).filter(q -> !q.isEmpty()).map(q -> "?" + q).orElse("");
        String fullUrl = "http://localhost:8082" + path + query;
        System.out.print(fullUrl);

        HttpRequest.Builder requestBuilder = HttpRequest.newBuilder()
                .uri(URI.create(fullUrl))
                .method(method, bodyPublisher(event));

        if (event.getHeaders() != null) {
            Map<String, String> headers = event.getHeaders();
            for (String name : List.of("accept", "cookie", "content-type", "authorization")) {
                Optional.ofNullable(headers.get(name))
                        .ifPresent(value -> requestBuilder.header(name, value));
            }
        }

        try {
            return toLambdaResponse(httpClient.send(requestBuilder.build(),
                    HttpResponse.BodyHandlers.ofByteArray()));
        } catch (Exception e) {
            //noinspection CallToPrintStackTrace
            e.printStackTrace();
            return errorResponse(e.getMessage());
        }
    }

    private static HttpRequest.BodyPublisher bodyPublisher(APIGatewayV2HTTPEvent event) {
        String method = Optional.ofNullable(event.getRequestContext())
                .map(APIGatewayV2HTTPEvent.RequestContext::getHttp)
                .map(APIGatewayV2HTTPEvent.RequestContext.Http::getMethod)
                .orElse("GET");
        if (method.equalsIgnoreCase("GET")) {
            return HttpRequest.BodyPublishers.noBody();
        }
        String body = Optional.ofNullable(event.getBody()).orElse("");
        if (event.getIsBase64Encoded()) {
            return HttpRequest.BodyPublishers.ofByteArray(Base64.getDecoder().decode(body));
        } else {
            return HttpRequest.BodyPublishers.ofString(body);
        }
    }

    private static APIGatewayV2HTTPResponse toLambdaResponse(HttpResponse<byte[]> response) throws IOException {
        System.out.printf(" received %d\n", response.statusCode());
        byte[] originalBody = response.body();

        ByteArrayOutputStream byteStream = new ByteArrayOutputStream();
        try (GZIPOutputStream gzipStream = new GZIPOutputStream(byteStream)) {
            gzipStream.write(originalBody);
        }
        byte[] compressedBody = byteStream.toByteArray();

        Map<String, String> headers = new HashMap<>();
        HttpHeaders rawHeaders = response.headers();
        rawHeaders.map().forEach((k, vList) -> headers.put(k, String.join(", ", vList)));
        headers.put("Content-Encoding", "gzip");
        System.out.printf(" returning %d\n", response.statusCode());
        return APIGatewayV2HTTPResponse.builder()
                .withStatusCode(response.statusCode())
                .withIsBase64Encoded(true)
                .withHeaders(headers)
                .withBody(Base64.getEncoder().encodeToString(compressedBody))
                .build();
    }

    private static APIGatewayV2HTTPResponse errorResponse(String message) {
        System.out.println("returning 503");
        return APIGatewayV2HTTPResponse.builder()
                .withStatusCode(503)
                .withBody(message)
                .withIsBase64Encoded(false)
                .build();
    }
}
