package com.dacia.nftpprobe;

import android.content.Context;
import android.util.Log;

import com.nng.core.SDK;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;

/**
 * Wrapper to run the real NNG SDK with NFTP support.
 * Extends SDK to use the proper initialization flow.
 */
public class NngEngine extends SDK {
    private static final String TAG = "NngEngine";
    private static NngEngine instance;
    private volatile boolean initialized;
    private String lastError;
    private Context appContext;

    static {
        System.loadLibrary("lib_base");
        System.loadLibrary("lib_memmgr");
        System.loadLibrary("lib_nng_sdk");
    }

    public static synchronized NngEngine getInstance() {
        if (instance == null) instance = new NngEngine();
        return instance;
    }

    private NngEngine() {
        super();
    }

    @Override
    protected String ProvideAPIKey(String key) {
        Log.d(TAG, "ProvideAPIKey: " + key);
        return "";
    }

    @Override
    protected String PassphraseProvider(String key) {
        Log.d(TAG, "PassphraseProvider: " + key);
        return "";
    }

    public String init(Context ctx) {
        if (initialized) return "Already initialized";
        appContext = ctx.getApplicationContext();

        try {
            // Use external files dir as rootPath (like the real app)
            File extDir = ctx.getExternalFilesDir("");
            if (extDir == null) extDir = ctx.getFilesDir();
            String rootPath = extDir.getAbsolutePath();
            File dataDir = new File(rootPath);
            // Extract nng_data contents directly into rootPath
            File marker = new File(rootPath, "xs_modules");
            deleteRecursive(marker);
            deleteRecursive(new File(rootPath, "yellowbox"));
            deleteRecursive(new File(rootPath, "project_config"));
            extractAssets(ctx, "nng_data", dataDir);
            Log.i(TAG, "NNG data at: " + dataDir.getAbsolutePath());

            // Configure the SDK - point at the extracted data dir
            // The SDK reads yellowbox/project.ini which sets skin=yellowbox
            // Then loads yellowbox/src/main.xs → connections.xs → socket + NFTP
            config.rootPath = rootPath;
            config.additionalResources = rootPath;
            config.threaded = true;

            // Set env vars like the real app
            android.system.Os.setenv("FILES_DIR", ctx.getFilesDir().getAbsolutePath(), true);
            android.system.Os.setenv("CACHE_DIR", ctx.getCacheDir().getAbsolutePath(), true);
            File extFiles = ctx.getExternalFilesDir(null);
            if (extFiles == null) extFiles = ctx.getFilesDir();
            android.system.Os.setenv("EXTERNAL_FILES_DIR", extFiles.getAbsolutePath(), true);
            // Boot script - try relative path from rootPath
            // Boot script — try absolute path
            String bootPath = new File(rootPath, "yellowbox/boot.xs").getAbsolutePath();
            Log.i(TAG, "Boot script path: " + bootPath);
            config.bootScript = new Configuration.BootScript(bootPath);
            // Verify via reflection
            try {
                java.lang.reflect.Field f = Configuration.BootScript.class.getDeclaredField("scriptPath");
                f.setAccessible(true);
                Log.i(TAG, "Boot script scriptPath: " + f.get(config.bootScript));
            } catch (Exception e) {
                Log.e(TAG, "Reflection failed", e);
            }

            // Set status callback
            config.onEngineStatusChange = status -> {
                Log.i(TAG, "Engine status: " + status);
            };

            Log.i(TAG, "Starting SDK with rootPath: " + dataDir.getAbsolutePath());
            InitializationResult result = Start();
            Log.i(TAG, "SDK Start result: " + result);

            if (result == InitializationResult.SUCCESS) {
                initialized = true;
                return "Engine initialized: " + result;
            } else {
                lastError = "Init failed: " + result;
                return lastError;
            }

        } catch (Exception e) {
            Log.e(TAG, "Init failed", e);
            lastError = e.toString();
            return "Init failed: " + e.getMessage();
        }
    }

    private void deleteRecursive(File f) {
        if (f.isDirectory()) {
            for (File c : f.listFiles()) deleteRecursive(c);
        }
        f.delete();
    }

    private void extractAssets(Context ctx, String assetPath, File destDir) throws Exception {
        String[] list = ctx.getAssets().list(assetPath);
        if (list == null || list.length == 0) {
            // It's a file
            destDir.getParentFile().mkdirs();
            try (InputStream in = ctx.getAssets().open(assetPath);
                 FileOutputStream out = new FileOutputStream(destDir)) {
                byte[] buf = new byte[8192];
                int len;
                while ((len = in.read(buf)) > 0) out.write(buf, 0, len);
            }
            Log.d(TAG, "Extracted: " + destDir.getAbsolutePath());
        } else {
            // It's a directory
            destDir.mkdirs();
            for (String child : list) {
                extractAssets(ctx, assetPath + "/" + child, new File(destDir, child));
            }
        }
    }

    public boolean isInitialized() {
        return initialized;
    }

    public String getLastError() {
        return lastError;
    }

    /**
     * The eval context is too limited to get symbol IDs.
     * Return info about what we know works.
     */
    public String getSymbolIds() {
        return "Eval context is limited - no Object, JSON, or imports available.\n\n" +
               "What works:\n" +
               "- Simple expressions: 1+1, 'hello'\n" +
               "- Symbol names: @ls -> 'ls'\n\n" +
               "What doesn't work:\n" +
               "- typeof, Object.keys, JSON.stringify\n" +
               "- import statements\n" +
               "- Getting numeric symbol IDs\n\n" +
               "Recommendation: Use Java NFTP with GetFile.\n" +
               "GetFile works - we got device.nng successfully.\n" +
               "QueryInfo needs matching symbol IDs which we can't get.";
    }

    /**
     * Connect to emulator via TCP using the real NNG SDK.
     */
    public String connectToEmulatorNng(String host, int port) {
        if (!initialized) {
            return "Engine not initialized";
        }

        try {
            com.nng.uie.api.androidConnection conn = com.nng.uie.api.androidConnection.INSTANCE;
            
            // Try importing our boot module and calling its functions
            String script = String.format(
                "import * as boot from 'boot.xs'; " +
                "await boot.nftpConnect('%s', %d); " +
                "boot.nftpLastResult()",
                host, port
            );
            
            Log.i(TAG, "Connect script: " + script);
            Object res = evalSync(conn, script, 15000);
            String result = formatResult(res);
            Log.i(TAG, "Connect result: " + result);
            
            return result;
            
        } catch (Exception e) {
            Log.e(TAG, "Connect failed", e);
            return "Error: " + e.getMessage();
        }
    }
    
    public Object evalSync(com.nng.uie.api.androidConnection conn, String script, long timeoutMs) {
        try {
            kotlinx.coroutines.CompletableDeferred<Object> deferred = 
                conn.getSession().asyncEval(null, script, new Object[]{});
            
            long start = System.currentTimeMillis();
            while (!deferred.isCompleted() && System.currentTimeMillis() - start < timeoutMs) {
                Thread.sleep(50);
            }
            
            if (!deferred.isCompleted()) {
                return "TIMEOUT";
            }
            return deferred.getCompleted();
        } catch (Exception e) {
            return "EXCEPTION: " + e.getMessage();
        }
    }
    
    public String formatResult(Object result) {
        if (result instanceof Object[]) {
            Object[] arr = (Object[]) result;
            if (arr.length > 0) {
                Object first = arr[0];
                if (first instanceof com.nng.uie.api.NngFailure) {
                    return "FAIL: " + ((com.nng.uie.api.NngFailure) first).getMessage();
                }
                return String.valueOf(first);
            }
            return "empty array";
        }
        return String.valueOf(result);
    }

    /**
     * Query disk info using the real NNG SDK.
     */
    public String queryDiskInfo() {
        if (!initialized) {
            return "Engine not initialized";
        }

        try {
            com.nng.uie.api.androidConnection conn = com.nng.uie.api.androidConnection.INSTANCE;
            
            // Query disk info
            String script = "await nftpQueryDiskInfo()";
            Log.i(TAG, "Query: " + script);
            Object res = evalSync(conn, script, 10000);
            String result = formatResult(res);
            Log.i(TAG, "DiskInfo: " + result);
            
            // Get status
            Object res2 = evalSync(conn, "nftpLastResult()", 5000);
            String status = formatResult(res2);
            
            return "DiskInfo: " + result + "\nStatus: " + status;
        } catch (Exception e) {
            Log.e(TAG, "Query failed", e);
            return "Error: " + e.getMessage();
        }
    }
}
