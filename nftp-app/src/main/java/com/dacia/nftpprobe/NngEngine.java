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
            // Extract xs_modules from assets to files dir
            String rootPath = ctx.getFilesDir().getAbsolutePath();
            File xsDir = new File(rootPath, "xs_modules");
            if (!xsDir.exists()) {
                extractAssets(ctx, "xs_modules", xsDir);
            }
            Log.i(TAG, "XS modules at: " + xsDir.getAbsolutePath());

            // Configure the SDK
            config.rootPath = rootPath;
            config.threaded = true;  // Run in background thread

            // Set boot script to load NFTP module
            config.bootScript = new Configuration.BootScript("xs_modules/core/nftp.xs");

            // Set status callback
            config.onEngineStatusChange = status -> {
                Log.i(TAG, "Engine status: " + status);
            };

            Log.i(TAG, "Starting SDK...");
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
}
