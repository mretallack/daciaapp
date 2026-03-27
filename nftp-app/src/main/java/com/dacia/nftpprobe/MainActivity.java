package com.dacia.nftpprobe;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.hardware.usb.UsbAccessory;
import android.hardware.usb.UsbManager;
import android.os.Build;
import android.os.Bundle;
import android.os.ParcelFileDescriptor;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;

import com.dacia.nftp.NftpProbe;

import java.io.FileInputStream;

public class MainActivity extends Activity {

    private static final String ACTION_USB_PERMISSION = "com.dacia.nftpprobe.USB_PERMISSION";
    private PendingIntent permissionIntent;
    private volatile boolean probeRunning = false;

    // Shared state
    private NftpProbe.Result lastResult;
    private final StringBuilder logBuffer = new StringBuilder();

    // Fragments (manual view switching)
    private View probeView, deviceView, explorerView, logView;
    private Button tabProbe, tabDevice, tabExplorer, tabLog;
    private Button activeTab;

    private final BroadcastReceiver usbReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (ACTION_USB_PERMISSION.equals(intent.getAction())) {
                UsbAccessory acc = intent.getParcelableExtra(UsbManager.EXTRA_ACCESSORY);
                if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                    log("USB permission granted");
                    if (acc != null) runProbeOverUsb(acc);
                } else {
                    log("USB permission denied");
                }
            } else if (UsbManager.ACTION_USB_ACCESSORY_DETACHED.equals(intent.getAction())) {
                log("USB accessory detached");
            }
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        tabProbe = findViewById(R.id.tabProbe);
        tabDevice = findViewById(R.id.tabDevice);
        tabExplorer = findViewById(R.id.tabExplorer);
        tabLog = findViewById(R.id.tabLog);

        FrameLayout frame = findViewById(R.id.contentFrame);

        probeView = getLayoutInflater().inflate(R.layout.fragment_probe, frame, false);
        deviceView = getLayoutInflater().inflate(R.layout.fragment_device, frame, false);
        explorerView = getLayoutInflater().inflate(R.layout.fragment_explorer, frame, false);
        logView = getLayoutInflater().inflate(R.layout.fragment_log, frame, false);

        frame.addView(probeView);
        frame.addView(deviceView);
        frame.addView(explorerView);
        frame.addView(logView);

        tabProbe.setOnClickListener(v -> showTab(tabProbe, probeView));
        tabDevice.setOnClickListener(v -> showTab(tabDevice, deviceView));
        tabExplorer.setOnClickListener(v -> { showTab(tabExplorer, explorerView); setupExplorer(); });
        tabLog.setOnClickListener(v -> { showTab(tabLog, logView); refreshLog(); });

        setupProbeTab();
        setupLogTab();
        setupExplorer();
        showTab(tabProbe, probeView);

        int flags = Build.VERSION.SDK_INT >= 31 ? PendingIntent.FLAG_MUTABLE : 0;
        Intent pi = new Intent(ACTION_USB_PERMISSION);
        pi.setPackage(getPackageName());
        permissionIntent = PendingIntent.getBroadcast(this, 0, pi, flags);

        IntentFilter filter = new IntentFilter(ACTION_USB_PERMISSION);
        filter.addAction(UsbManager.ACTION_USB_ACCESSORY_DETACHED);
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            registerReceiver(usbReceiver, filter);
        }

        handleIntent(getIntent());
    }

    private void showTab(Button tab, View view) {
        probeView.setVisibility(View.GONE);
        deviceView.setVisibility(View.GONE);
        explorerView.setVisibility(View.GONE);
        logView.setVisibility(View.GONE);
        view.setVisibility(View.VISIBLE);

        tabProbe.setAlpha(0.5f);
        tabDevice.setAlpha(0.5f);
        tabExplorer.setAlpha(0.5f);
        tabLog.setAlpha(0.5f);
        tab.setAlpha(1.0f);
        activeTab = tab;
    }

    // --- Probe Tab ---

    private void setupProbeTab() {
        probeView.findViewById(R.id.btnConnect).setOnClickListener(v -> {
            android.widget.EditText editHost = probeView.findViewById(R.id.editHost);
            String host = editHost.getText().toString().trim();
            if (!host.isEmpty()) runProbeOverTcp(host, 9876);
        });
    }

    private void updateProbeStatus(String status) {
        runOnUiThread(() -> {
            android.widget.TextView txt = probeView.findViewById(R.id.txtStatus);
            txt.setText(status);
        });
    }

    private void updateDeviceTab() {
        runOnUiThread(() -> {
            android.widget.TextView txt = deviceView.findViewById(R.id.txtDeviceStatus);
            android.widget.LinearLayout layout = deviceView.findViewById(R.id.deviceInfoLayout);

            if (lastResult == null || !lastResult.isSuccess()) {
                txt.setText("Not connected");
                return;
            }
            txt.setText("Connected: " + lastResult.serverName + " v" + lastResult.serverVersion);

            // Remove old info rows (keep status text)
            while (layout.getChildCount() > 1) layout.removeViewAt(1);

            addInfoRow(layout, "Server", lastResult.serverName);
            addInfoRow(layout, "NFTP Version", String.valueOf(lastResult.serverVersion));
            if (lastResult.deviceNng != null) {
                addInfoRow(layout, "device.nng size", lastResult.deviceNng.length + " bytes");
                addInfoRow(layout, "device.nng hex", com.dacia.nftp.NftpProbe.hex(lastResult.deviceNng, 64));
            }
        });
    }

    private void addInfoRow(android.widget.LinearLayout layout, String label, String value) {
        android.widget.TextView tv = new android.widget.TextView(this);
        tv.setText(label + ": " + value);
        tv.setTextSize(13);
        tv.setPadding(0, 4, 0, 4);
        layout.addView(tv);
    }

    // --- Explorer Tab ---

    private void setupExplorer() {
        androidx.recyclerview.widget.RecyclerView rv = explorerView.findViewById(R.id.recyclerFiles);
        rv.setLayoutManager(new androidx.recyclerview.widget.LinearLayoutManager(this));
        java.util.List<com.dacia.nftp.HeadUnitExplorer.FileEntry> entries = com.dacia.nftp.HeadUnitExplorer.getDirectoryTree();
        rv.setAdapter(new ExplorerAdapter(entries, entry -> {
            log("Selected: " + entry.path + (entry.isDir ? " (dir)" : " (file)"));
            if (!entry.isDir) {
                showFileDetail(entry);
            }
        }));
    }

    private void showFileDetail(com.dacia.nftp.HeadUnitExplorer.FileEntry entry) {
        // Simple dialog for now
        android.app.AlertDialog.Builder b = new android.app.AlertDialog.Builder(this);
        b.setTitle(entry.name);
        b.setMessage("Path: " + entry.path);
        b.setNeutralButton("Close", null);
        b.show();
    }

    // --- Log Tab ---

    private void setupLogTab() {
        logView.findViewById(R.id.btnClear).setOnClickListener(v -> {
            synchronized (logBuffer) { logBuffer.setLength(0); }
            refreshLog();
        });
    }

    private void refreshLog() {
        runOnUiThread(() -> {
            android.widget.TextView txt = logView.findViewById(R.id.txtLog);
            synchronized (logBuffer) { txt.setText(logBuffer.toString()); }
            android.widget.ScrollView sv = logView.findViewById(R.id.scrollLog);
            sv.post(() -> sv.fullScroll(View.FOCUS_DOWN));
        });
    }

    // --- Connection ---

    @Override
    protected void onDestroy() {
        super.onDestroy();
        unregisterReceiver(usbReceiver);
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        handleIntent(intent);
    }

    private void handleIntent(Intent intent) {
        if (intent == null) return;
        String emuHost = intent.getStringExtra("emulator_host");
        if (emuHost != null) { runProbeOverTcp(emuHost, 9876); return; }
        UsbAccessory accessory = intent.getParcelableExtra(UsbManager.EXTRA_ACCESSORY);
        if (accessory != null) {
            UsbManager usb = (UsbManager) getSystemService(USB_SERVICE);
            if (usb.hasPermission(accessory)) {
                log("Have USB permission");
                runProbeOverUsb(accessory);
            } else {
                log("Requesting USB permission...");
                usb.requestPermission(accessory, permissionIntent);
            }
        }
    }

    private void runProbeOverTcp(String host, int port) {
        log("Connecting to " + host + ":" + port + "...");
        updateProbeStatus("Connecting...");
        new Thread(() -> {
            try (java.net.Socket sock = new java.net.Socket(host, port)) {
                lastResult = NftpProbe.run(sock.getInputStream(), sock.getOutputStream(), this::log);
                updateProbeStatus(lastResult.isSuccess() ? "Connected: " + lastResult.serverName : "Failed: " + lastResult.error);
                updateDeviceTab();
            } catch (Exception e) {
                log("TCP error: " + e.getMessage());
                updateProbeStatus("Error: " + e.getMessage());
            }
        }).start();
    }

    private void runProbeOverUsb(UsbAccessory accessory) {
        if (probeRunning) { log("Probe already running"); return; }
        probeRunning = true;
        log("Opening USB accessory: " + accessory.getManufacturer() + "/" + accessory.getModel());
        updateProbeStatus("Connecting via USB...");
        UsbManager usb = (UsbManager) getSystemService(USB_SERVICE);
        new Thread(() -> {
            try {
                ParcelFileDescriptor pfd = usb.openAccessory(accessory);
                if (pfd == null) { log("Failed to open accessory"); probeRunning = false; return; }
                log("Accessory fd=" + pfd.getFd());
                java.io.FileDescriptor rawFd = pfd.getFileDescriptor();
                FileInputStream in = new FileInputStream(rawFd);
                try { int avail = in.available(); if (avail > 0) log("Pre-Init bytes: " + avail); }
                catch (Exception e) { log("available() not supported: " + e.getMessage()); }

                java.io.OutputStream out = new java.io.OutputStream() {
                    public void write(int b) throws java.io.IOException { write(new byte[]{(byte) b}, 0, 1); }
                    public void write(byte[] b, int off, int len) throws java.io.IOException {
                        try { android.system.Os.write(rawFd, b, off, len); }
                        catch (android.system.ErrnoException e) { throw new java.io.IOException(e); }
                    }
                };
                try {
                    lastResult = NftpProbe.run(in, out, this::log);
                    updateProbeStatus(lastResult.isSuccess() ? "Connected: " + lastResult.serverName : "Failed: " + lastResult.error);
                    updateDeviceTab();
                } finally { in.close(); pfd.close(); probeRunning = false; }
            } catch (Exception e) {
                log("USB error: " + e.getMessage());
                updateProbeStatus("Error: " + e.getMessage());
                probeRunning = false;
            }
        }).start();
    }

    private void log(String msg) {
        android.util.Log.i("NftpProbe", msg);
        synchronized (logBuffer) { logBuffer.append(msg).append('\n'); }
        if (activeTab == tabLog) refreshLog();
    }
}
