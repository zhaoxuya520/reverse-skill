package com.burpmcp;

import burp.api.montoya.MontoyaApi;
import burp.api.montoya.core.Annotations;
import burp.api.montoya.core.ByteArray;
import burp.api.montoya.http.message.requests.HttpRequest;
import burp.api.montoya.http.message.responses.HttpResponse;
import burp.api.montoya.proxy.Proxy;
import burp.api.montoya.proxy.ProxyHttpRequestResponse;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ProxyHistoryTest {
    @TempDir Path temporaryHome;
    private final List<ProxyHttpRequestResponse> history = new ArrayList<>();
    private final List<AtomicReference<String>> notes = new ArrayList<>();
    private McpHttpServer server;
    private Method dispatch;

    @BeforeEach
    void setUp() throws Exception {
        addEntry("GET", "/keep/old", 200);
        addEntry("POST", "/skip", 404);
        addEntry("GET", "/keep/new", 200);
        addEntry("POST", "/keep/latest", 201);
        Proxy proxy = fixed(Proxy.class, Map.of("history", history));
        MontoyaApi api = fixed(MontoyaApi.class, Map.of("proxy", proxy));

        // Construct the real dispatcher without starting a server. Its token
        // writer is confined to this test's temporary directory.
        String originalHome = System.getProperty("user.home");
        String originalToken = System.getProperty("burp.mcp.token");
        try {
            System.setProperty("user.home", temporaryHome.toString());
            System.setProperty("burp.mcp.token", "history-fixture-token");
            server = new McpHttpServer(api, 0);
        } finally {
            restoreProperty("user.home", originalHome);
            restoreProperty("burp.mcp.token", originalToken);
        }
        dispatch = McpHttpServer.class.getDeclaredMethod("dispatch", String.class, JsonObject.class);
        dispatch.setAccessible(true);
    }

    @Test
    void listIndexesResolveTheSameEntriesAfterFilteringAndPagination() throws Exception {
        assertPage("{}", 4, List.of(3, 2, 1, 0));
        assertPage("{\"url_filter\":\"/keep\"}", 3, List.of(3, 2, 0));
        assertPage("{\"method_filter\":\"get\"}", 2, List.of(2, 0));
        assertPage("{\"status_filter\":200}", 2, List.of(2, 0));
        assertPage("{\"offset\":1,\"limit\":2}", 4, List.of(2, 1));
        assertPage("{\"url_filter\":\"/keep\",\"method_filter\":\"GET\","
                + "\"status_filter\":200,\"offset\":1,\"limit\":1}", 2, List.of(0));
    }

    @Test
    void annotatingAListedIndexChangesOnlyTheSelectedEntry() throws Exception {
        JsonObject listed = call("proxy_history", "{\"url_filter\":\"/keep/latest\"}")
                .getAsJsonArray("items").get(0).getAsJsonObject();
        int index = listed.get("index").getAsInt();
        JsonObject result = call("annotate", "{\"index\":" + index + ",\"note\":\"selected\"}");
        assertTrue(result.get("success").getAsBoolean());
        assertEquals(List.of("", "", "", "selected"), notes.stream().map(AtomicReference::get).toList());
    }

    @Test
    void agreesWithSearchAndAnnotationHistoryIndexConventions() throws Exception {
        notes.get(2).set("selected");
        JsonObject listed = call("proxy_history", "{\"url_filter\":\"/keep/new\"}")
                .getAsJsonArray("items").get(0).getAsJsonObject();
        JsonObject searched = call("search_history", "{\"regex\":\"/keep/new\"}")
                .getAsJsonArray("items").get(0).getAsJsonObject();
        JsonObject annotated = call("proxy_history_filtered", "{\"has_notes\":\"true\"}")
                .getAsJsonArray("items").get(0).getAsJsonObject();
        assertEquals(searched.get("index"), listed.get("index"));
        assertEquals(annotated.get("index"), listed.get("index"));
    }

    @Test
    void emptyResultsKeepTotalAndPaginationSemantics() throws Exception {
        assertPage("{\"url_filter\":\"missing\"}", 0, List.of());
        assertPage("{\"offset\":9}", 4, List.of());
        assertPage("{\"limit\":0}", 4, List.of());
        history.clear();
        assertPage("{}", 0, List.of());
    }

    private void assertPage(String params, int total, List<Integer> expectedIndexes) throws Exception {
        JsonObject result = call("proxy_history", params);
        assertEquals(total, result.get("total").getAsInt(), params);
        JsonArray items = result.getAsJsonArray("items");
        List<Integer> indexes = new ArrayList<>();
        for (JsonElement item : items) {
            JsonObject row = item.getAsJsonObject();
            int index = row.get("index").getAsInt();
            indexes.add(index);
            JsonObject detail = call("proxy_detail", "{\"index\":" + index + "}");
            assertEquals(row.get("url"), detail.get("url"), params + " list -> detail");
            assertEquals(row.get("method"), detail.get("method"), params);
            assertEquals(row.get("status"), detail.get("status"), params);
        }
        assertEquals(expectedIndexes, indexes, params);
    }

    private JsonObject call(String tool, String params) throws Exception {
        JsonObject result = (JsonObject) dispatch.invoke(server, tool, JsonParser.parseString(params).getAsJsonObject());
        assertFalse(result.has("error"), () -> tool + ": " + result);
        return result;
    }

    private void addEntry(String method, String path, int status) {
        String url = "https://fixture.invalid" + path;
        HttpRequest request = fixed(HttpRequest.class, Map.of("method", method, "url", url, "toString", method + " " + path));
        ByteArray body = fixed(ByteArray.class, Map.of("length", path.length()));
        HttpResponse response = fixed(HttpResponse.class, Map.of("statusCode", (short) status, "body", body, "toString", path));
        AtomicReference<String> note = new AtomicReference<>("");
        notes.add(note);
        Annotations annotations = mock(Annotations.class, (ignored, called, arguments) -> {
            if (called.getName().equals("notes")) return note.get();
            if (called.getName().equals("setNotes")) {
                note.set((String) arguments[0]);
                return null;
            }
            throw new AssertionError("Unexpected annotations method: " + called);
        });
        history.add(fixed(ProxyHttpRequestResponse.class, Map.of(
                "finalRequest", request, "response", response, "annotations", annotations)));
    }

    private static <T> T fixed(Class<T> type, Map<String, Object> values) {
        return mock(type, (ignored, method, arguments) -> {
            if (values.containsKey(method.getName())) return values.get(method.getName());
            throw new AssertionError("Unexpected fixture method: " + method);
        });
    }

    private static <T> T mock(Class<T> type, InvocationHandler handler) {
        return type.cast(java.lang.reflect.Proxy.newProxyInstance(type.getClassLoader(), new Class<?>[]{type}, handler));
    }

    private static void restoreProperty(String name, String previousValue) {
        if (previousValue == null) System.clearProperty(name);
        else System.setProperty(name, previousValue);
    }
}
