package com.burpmcp;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import fi.iki.elonen.NanoHTTPD;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CancellationException;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Future;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ServerLifecycleTest {
    @TempDir Path temporaryHome;
    private McpHttpServer server;
    private ThreadPoolExecutor executor;

    @BeforeEach
    void setUp() throws Exception {
        String originalHome = System.getProperty("user.home");
        String originalToken = System.getProperty("burp.mcp.token");
        try {
            System.setProperty("user.home", temporaryHome.toString());
            System.setProperty("burp.mcp.token", "lifecycle-fixture-token");
            // No HTTP listener is started and no Montoya API is connected.
            server = new McpHttpServer(null, 0);
        } finally {
            restoreProperty("user.home", originalHome);
            restoreProperty("burp.mcp.token", originalToken);
        }
        Field field = McpHttpServer.class.getDeclaredField("threadPool");
        field.setAccessible(true);
        executor = (ThreadPoolExecutor) field.get(server);
    }

    @AfterEach
    void cleanUpFixtureWorkers() throws Exception {
        // Also clean up when running these regressions against the old server.
        for (Runnable task : executor.shutdownNow()) {
            if (task instanceof Future<?> future) future.cancel(true);
        }
        assertTrue(executor.awaitTermination(5, TimeUnit.SECONDS));
    }

    @Test
    void stopsAWorkerCreatedByTheRealParallelDispatcher() throws Exception {
        Method dispatch = McpHttpServer.class.getDeclaredMethod("dispatch", String.class, JsonObject.class);
        dispatch.setAccessible(true);
        JsonObject params = JsonParser.parseString("{\"requests\":[{\"method\":\"GET\","
                + "\"url\":\"invalid URL without scheme\"}]}").getAsJsonObject();
        // URL parsing fails before any HTTP service is created. The actual
        // parallel dispatch path still starts an otherwise idle pool worker.
        dispatch.invoke(server, "send_request_parallel", params);
        assertEquals(1, executor.getPoolSize());
        assertFalse(executor.isShutdown());

        server.stop();

        assertTrue(executor.isShutdown());
        assertTrue(executor.awaitTermination(5, TimeUnit.SECONDS));
        assertEquals(0, executor.getPoolSize());
        assertThrows(RejectedExecutionException.class, () -> executor.submit(() -> {}));
    }

    @Test
    void stoppingAnUnusedServerTwiceIsSafe() {
        assertEquals(0, executor.getPoolSize());
        server.stop();
        server.stop();
        assertTrue(executor.isShutdown());
        assertTrue(executor.isTerminated());
        assertThrows(RejectedExecutionException.class, () -> executor.submit(() -> {}));
    }

    @Test
    void interruptsActiveTasksAndCancelsQueuedFuturesToReleaseWaiters() throws Exception {
        int workers = executor.getCorePoolSize();
        CountDownLatch started = new CountDownLatch(workers);
        CountDownLatch interrupted = new CountDownLatch(workers);
        CountDownLatch release = new CountDownLatch(1);
        List<Future<?>> active = new ArrayList<>();
        List<Future<?>> queued = new ArrayList<>();
        CompletableFuture<String> waitingResult = new CompletableFuture<>();
        CountDownLatch waiterStarted = new CountDownLatch(1);
        Thread waiter = null;
        try {
            for (int i = 0; i < workers; i++) {
                active.add(executor.submit(() -> {
                    started.countDown();
                    try {
                        release.await();
                    } catch (InterruptedException expected) {
                        interrupted.countDown();
                        Thread.currentThread().interrupt();
                    }
                }));
            }
            assertTrue(started.await(5, TimeUnit.SECONDS));
            for (int i = 0; i < 3; i++) queued.add(executor.submit(() -> "must not run"));
            assertEquals(3, executor.getQueue().size());
            waiter = new Thread(() -> {
                waiterStarted.countDown();
                try {
                    queued.get(0).get();
                    waitingResult.complete("ran");
                } catch (CancellationException expected) {
                    waitingResult.complete("cancelled");
                } catch (Exception error) {
                    waitingResult.completeExceptionally(error);
                }
            }, "queued-future-fixture-waiter");
            waiter.start();
            assertTrue(waiterStarted.await(5, TimeUnit.SECONDS));

            server.stop();

            assertTrue(executor.isShutdown());
            assertTrue(interrupted.await(5, TimeUnit.SECONDS));
            assertTrue(executor.awaitTermination(5, TimeUnit.SECONDS));
            for (Future<?> future : queued) {
                assertTrue(future.isCancelled());
                assertThrows(CancellationException.class, () -> future.get(1, TimeUnit.SECONDS));
            }
            assertEquals("cancelled", waitingResult.get(5, TimeUnit.SECONDS));
            for (Future<?> future : active) future.get(5, TimeUnit.SECONDS);
        } finally {
            release.countDown();
            for (Future<?> future : active) future.cancel(true);
            for (Future<?> future : queued) future.cancel(true);
            if (waiter != null) {
                waiter.interrupt();
                waiter.join(5000);
                assertFalse(waiter.isAlive());
            }
        }
    }

    @Test
    void cleansUpWorkersEvenWhenTheUnderlyingServerStopThrows() {
        AssertionError failure = new AssertionError("fixture HTTP shutdown failure");
        server.setAsyncRunner(new NanoHTTPD.AsyncRunner() {
            @Override public void closeAll() { throw failure; }
            @Override public void closed(NanoHTTPD.ClientHandler handler) { throw new AssertionError("unused"); }
            @Override public void exec(NanoHTTPD.ClientHandler handler) { throw new AssertionError("unused"); }
        });

        assertSame(failure, assertThrows(AssertionError.class, server::stop));
        assertTrue(executor.isShutdown());
        assertTrue(executor.isTerminated());
    }

    private static void restoreProperty(String name, String previousValue) {
        if (previousValue == null) System.clearProperty(name);
        else System.setProperty(name, previousValue);
    }
}
