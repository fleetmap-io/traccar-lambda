import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayV2HTTPEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayV2HTTPResponse;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.http.HttpHeaders;
import java.time.Duration;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;


public class Handler implements RequestHandler<APIGatewayV2HTTPEvent, APIGatewayV2HTTPResponse> {

    private static final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(2))
            .build();

    private static final AtomicBoolean started = new AtomicBoolean(false);

    static {
        if (started.compareAndSet(false, true)) {
            new Thread(() -> {
                try {
                    System.out.println("Starting Traccar...");
                    org.traccar.Main.main(new String[]{"traccar.xml"});
                } catch (Exception e) {
                    System.err.printf("Traccar startup failed %s", e);
                }
            }).start();
        }
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

        HttpRequest.Builder requestBuilder = HttpRequest.newBuilder()
                .uri(URI.create(fullUrl))
                .timeout(Duration.ofSeconds(10))
                .method(method, bodyPublisher(event));

        if (event.getHeaders() != null) {
            Map<String, String> headers = event.getHeaders();
            System.out.println(headers.toString());
            for (String name : List.of("content-type", "cookie")) {
                Optional.ofNullable(headers.get(name))
                        .ifPresent(value -> requestBuilder.header(name, value));
            }
        }


        final int maxRetries = 4;
        for (int attempt = 1; true; attempt++) {
            try {
                HttpResponse<byte[]> response = httpClient.send(requestBuilder.build(), HttpResponse.BodyHandlers.ofByteArray());
                return toLambdaResponse(response);
            } catch (Exception e) {
                if (attempt < maxRetries) {
                    System.out.printf("⚠️ Exception on attempt %d: %s. Retrying...\n", attempt, e.getMessage());
                    try {
                        Thread.sleep(1000);
                    } catch (InterruptedException ignored) {}
                } else {
                    return errorResponse(e.getMessage());
                }
            }
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
        return HttpRequest.BodyPublishers.ofString(body);
    }

    private static APIGatewayV2HTTPResponse toLambdaResponse(HttpResponse<byte[]> response) {
        Map<String, String> headers = new HashMap<>();
        HttpHeaders rawHeaders = response.headers();
        rawHeaders.map().forEach((k, vList) -> headers.put(k, String.join(", ", vList)));

        return APIGatewayV2HTTPResponse.builder()
                .withStatusCode(response.statusCode())
                .withIsBase64Encoded(true)
                .withHeaders(headers)
                .withBody(Base64.getEncoder().encodeToString(response.body()))
                .build();
    }

    private static APIGatewayV2HTTPResponse errorResponse(String message) {
        return APIGatewayV2HTTPResponse.builder()
                .withStatusCode(503)
                .withBody(message)
                .withHeaders(Map.of("Content-Type", "text/plain"))
                .withIsBase64Encoded(false)
                .build();
    }

    public static void main(String[] args) {
        Handler h = new Handler();
        APIGatewayV2HTTPEvent event = new APIGatewayV2HTTPEvent();
        event.setRawPath("/");
        event.setRequestContext(new APIGatewayV2HTTPEvent.RequestContext() {{
            setHttp(new Http() {{
                setMethod("GET");
                setPath("/");
            }});
        }});
        event.setHeaders(Map.of("User-Agent", "test"));

        APIGatewayV2HTTPResponse resp = h.handleRequest(event, null);
        System.out.println("Status: " + resp.getStatusCode());
        System.out.println("Body: " + new String(Base64.getDecoder().decode(resp.getBody())));
    }

}
