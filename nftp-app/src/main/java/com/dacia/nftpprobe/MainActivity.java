package com.dacia.nftpprobe;

import android.app.Activity;
import android.app.AlertDialog;
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
import android.util.Log;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.dacia.nftp.HeadUnitExplorer;
import com.dacia.nftp.HexDump;
import com.dacia.nftp.NftpProbe;

import java.io.FileInputStream;
import java.util.ArrayList;
import java.util.List;

public class MainActivity extends Activity {

    private static final String ACTION_USB_PERMISSION = "com.dacia.nftpprobe.USB_PERMISSION";
    private PendingIntent permissionIntent;
    private volatile boolean probeRunning = false;

    // Shared connection
    private HeadUnitExplorer explorer;
    private final StringBuilder logBuffer = new StringBuilder();

    // Views
    private View probeView, deviceView, explorerView, logView;
    private Button tabProbe, tabDevice, tabExplorer, tabLog;
    private Button activeTab;

    // Explorer state
    private ExplorerAdapter explorerAdapter;
    private String currentPath = "/";
    private final List<String> pathStack = new ArrayList<>();

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
                explorer = null;
                updateAllTabs();
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
        tabDevice.setOnClickListener(v -> { showTab(tabDevice, deviceView); updateDeviceTab(); });
        tabExplorer.setOnClickListener(v -> { showTab(tabExplorer, explorerView); refreshExplorer(); });
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

    // ---------------------------------------------------------------
    // Probe Tab
    // ---------------------------------------------------------------

    private void setupProbeTab() {
        probeView.findViewById(R.id.btnConnect).setOnClickListener(v -> {
            EditText editHost = probeView.findViewById(R.id.editHost);
            String host = editHost.getText().toString().trim();
            if (!host.isEmpty()) runProbeOverTcp(host, 9876);
        });
    }

    private void updateProbeStatus(String status) {
        runOnUiThread(() -> {
            TextView txt = probeView.findViewById(R.id.txtStatus);
            txt.setText(status);
        });
    }

    // ---------------------------------------------------------------
    // Device Tab
    // ---------------------------------------------------------------

    private void updateDeviceTab() {
        runOnUiThread(() -> {
            TextView txt = deviceView.findViewById(R.id.txtDeviceStatus);
            LinearLayout layout = deviceView.findViewById(R.id.deviceInfoLayout);

            // Remove old info rows (keep status text)
            while (layout.getChildCount() > 1) layout.removeViewAt(1);

            if (explorer == null || !explorer.isConnected()) {
                txt.setText("Not connected");
                return;
            }

            txt.setText("Connected: " + explorer.getServerName() + " v" + explorer.getServerVersion());

            // Device info
            HeadUnitExplorer.DeviceInfo info = explorer.getDeviceInfo();
            if (info != null) {
                if (info.swid != null) addInfoRow(layout, "SWID", info.swid);
                if (info.vin != null) addInfoRow(layout, "VIN", info.vin);
                if (info.igoVersion != null) addInfoRow(layout, "iGo Version", info.igoVersion);
                if (info.appcid != null) addInfoRow(layout, "APPCID", info.appcid);
                if (info.agentBrand != null) addInfoRow(layout, "Brand", info.agentBrand);
                if (info.modelName != null) addInfoRow(layout, "Model", info.modelName);
                if (info.brandName != null) addInfoRow(layout, "Brand Name", info.brandName);
            }

            // Disk info
            HeadUnitExplorer.DiskInfo di = explorer.getDiskInfo();
            if (di != null && di.size > 0) {
                String total = formatSize(di.size);
                String avail = formatSize(di.available);
                long pct = 100 - (di.available * 100 / di.size);
                addInfoRow(layout, "Disk", avail + " free of " + total + " (" + pct + "% used)");
            } else {
                addInfoRow(layout, "Disk", "unavailable");
            }

            // device.nng fallback
            if (info == null && explorer.getDeviceNng() != null) {
                addInfoRow(layout, "device.nng", explorer.getDeviceNng().length + " bytes");
                addInfoRow(layout, "Hex", NftpProbe.hex(explorer.getDeviceNng(), 64));
            }
        });
    }

    private void addInfoRow(LinearLayout layout, String label, String value) {
        TextView tv = new TextView(this);
        tv.setText(label + ": " + value);
        tv.setTextSize(13);
        tv.setPadding(0, 4, 0, 4);
        layout.addView(tv);
    }

    // ---------------------------------------------------------------
    // Explorer Tab
    // ---------------------------------------------------------------

    private void setupExplorer() {
        androidx.recyclerview.widget.RecyclerView rv = explorerView.findViewById(R.id.recyclerFiles);
        rv.setLayoutManager(new androidx.recyclerview.widget.LinearLayoutManager(this));
        List<HeadUnitExplorer.FileEntry> entries = HeadUnitExplorer.getDirectoryTree();
        explorerAdapter = new ExplorerAdapter(entries, this::onExplorerItemClick);
        rv.setAdapter(explorerAdapter);
    }

    private void refreshExplorer() {
        runOnUiThread(() -> {
            TextView txtPath = explorerView.findViewById(R.id.txtPath);
            txtPath.setText(currentPath);
        });
        if (explorer == null || !explorer.isConnected()) {
            explorerAdapter.updateEntries(HeadUnitExplorer.getDirectoryTree());
            return;
        }
        new Thread(() -> {
            List<HeadUnitExplorer.FileEntry> entries = explorer.listDirectory(currentPath);
            if (entries == null) {
                entries = HeadUnitExplorer.getDirectoryTree();
                log("@ls failed, using hardcoded tree");
            }
            // Add back entry if not at root
            List<HeadUnitExplorer.FileEntry> display = new ArrayList<>();
            if (!"/".equals(currentPath) && !currentPath.isEmpty()) {
                display.add(new HeadUnitExplorer.FileEntry("⬆ ..", parentPath(currentPath), true));
            }
            display.addAll(entries);
            final List<HeadUnitExplorer.FileEntry> finalEntries = display;
            runOnUiThread(() -> explorerAdapter.updateEntries(finalEntries));
        }).start();
    }

    private void onExplorerItemClick(HeadUnitExplorer.FileEntry entry) {
        if (entry.isDir) {
            if (entry.name.startsWith("⬆")) {
                // Go up
                currentPath = entry.path;
            } else {
                pathStack.add(currentPath);
                currentPath = entry.path.endsWith("/") ? entry.path : entry.path + "/";
            }
            refreshExplorer();
        } else {
            showFileDetail(entry);
        }
    }

    private String parentPath(String path) {
        String p = path.endsWith("/") ? path.substring(0, path.length() - 1) : path;
        int idx = p.lastIndexOf('/');
        if (idx <= 0) return "/";
        return p.substring(0, idx + 1);
    }

    private void showFileDetail(HeadUnitExplorer.FileEntry entry) {
        View dlgView = getLayoutInflater().inflate(R.layout.dialog_file_detail, null);
        TextView txtPath = dlgView.findViewById(R.id.txtFilePath);
        TextView txtInfo = dlgView.findViewById(R.id.txtFileInfo);
        TextView txtResult = dlgView.findViewById(R.id.txtResult);
        Button btnMd5 = dlgView.findViewById(R.id.btnMd5);
        Button btnSha1 = dlgView.findViewById(R.id.btnSha1);
        Button btnDownload = dlgView.findViewById(R.id.btnDownload);
        Button btnSave = dlgView.findViewById(R.id.btnSave);

        txtPath.setText(entry.path);
        txtInfo.setText(entry.size > 0 ? formatSize(entry.size) : "File");

        final byte[][] downloadedData = {null};

        AlertDialog dlg = new AlertDialog.Builder(this)
                .setView(dlgView).setNeutralButton("Close", null).create();

        btnMd5.setOnClickListener(v -> {
            if (explorer == null || !explorer.isConnected()) {
                txtResult.setText("Not connected");
                return;
            }
            btnMd5.setEnabled(false);
            txtResult.setText("Computing MD5...");
            new Thread(() -> {
                try {
                    String hash = explorer.getChecksum(entry.path, 0);
                    runOnUiThread(() -> { txtResult.setText("MD5: " + hash); btnMd5.setEnabled(true); });
                } catch (Exception e) {
                    runOnUiThread(() -> { txtResult.setText("Error: " + e.getMessage()); btnMd5.setEnabled(true); });
                }
            }).start();
        });

        btnSha1.setOnClickListener(v -> {
            if (explorer == null || !explorer.isConnected()) {
                txtResult.setText("Not connected");
                return;
            }
            btnSha1.setEnabled(false);
            txtResult.setText("Computing SHA1...");
            new Thread(() -> {
                try {
                    String hash = explorer.getChecksum(entry.path, 1);
                    runOnUiThread(() -> { txtResult.setText("SHA1: " + hash); btnSha1.setEnabled(true); });
                } catch (Exception e) {
                    runOnUiThread(() -> { txtResult.setText("Error: " + e.getMessage()); btnSha1.setEnabled(true); });
                }
            }).start();
        });

        btnDownload.setOnClickListener(v -> {
            if (explorer == null || !explorer.isConnected()) {
                txtResult.setText("Not connected");
                return;
            }
            btnDownload.setEnabled(false);
            txtResult.setText("Downloading...");
            new Thread(() -> {
                try {
                    byte[] data = explorer.readFile(entry.path);
                    downloadedData[0] = data;
                    String hex = HexDump.format(data, 0, Math.min(data.length, 512));
                    runOnUiThread(() -> { txtResult.setText(data.length + " bytes\n" + hex); btnDownload.setEnabled(true); });
                } catch (Exception e) {
                    runOnUiThread(() -> { txtResult.setText("Error: " + e.getMessage()); btnDownload.setEnabled(true); });
                }
            }).start();
        });

        btnSave.setOnClickListener(v -> {
            if (downloadedData[0] == null) {
                txtResult.setText("Download first");
                return;
            }
            try {
                java.io.File dir = android.os.Environment.getExternalStoragePublicDirectory(
                        android.os.Environment.DIRECTORY_DOWNLOADS);
                java.io.File file = new java.io.File(dir, entry.name);
                try (java.io.FileOutputStream fos = new java.io.FileOutputStream(file)) {
                    fos.write(downloadedData[0]);
                }
                log("Saved " + entry.path + " to " + file.getAbsolutePath());
                txtResult.setText("Saved to: " + file.getAbsolutePath());
            } catch (Exception e) {
                txtResult.setText("Save error: " + e.getMessage());
            }
        });

        dlg.show();
    }

    // ---------------------------------------------------------------
    // Log Tab
    // ---------------------------------------------------------------

    private void setupLogTab() {
        logView.findViewById(R.id.btnClear).setOnClickListener(v -> {
            synchronized (logBuffer) { logBuffer.setLength(0); }
            refreshLog();
        });
    }

    private void refreshLog() {
        runOnUiThread(() -> {
            TextView txt = logView.findViewById(R.id.txtLog);
            synchronized (logBuffer) { txt.setText(logBuffer.toString()); }
            ScrollView sv = logView.findViewById(R.id.scrollLog);
            sv.post(() -> sv.fullScroll(View.FOCUS_DOWN));
        });
    }

    // ---------------------------------------------------------------
    // Connection
    // ---------------------------------------------------------------

    private void updateAllTabs() {
        updateProbeStatus(explorer != null && explorer.isConnected()
                ? "Connected: " + explorer.getServerName()
                : "Not connected");
        updateDeviceTab();
        if (activeTab == tabExplorer) refreshExplorer();
    }

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
                runProbeOverUsb(accessory);
            } else {
                usb.requestPermission(accessory, permissionIntent);
            }
        }
    }

    private void runProbeOverTcp(String host, int port) {
        log("Connecting to " + host + ":" + port + "...");
        updateProbeStatus("Connecting...");
        new Thread(() -> {
            try {
                java.net.Socket sock = new java.net.Socket(host, port);
                HeadUnitExplorer exp = new HeadUnitExplorer();
                exp.connect(sock.getInputStream(), sock.getOutputStream(), this::log);
                explorer = exp;
                updateAllTabs();
            } catch (Exception e) {
                log("TCP error: " + e.getMessage());
                explorer = null;
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
                java.io.FileDescriptor rawFd = pfd.getFileDescriptor();
                FileInputStream in = new FileInputStream(rawFd);
                java.io.OutputStream out = new java.io.OutputStream() {
                    public void write(int b) throws java.io.IOException { write(new byte[]{(byte) b}, 0, 1); }
                    public void write(byte[] b, int off, int len) throws java.io.IOException {
                        try { android.system.Os.write(rawFd, b, off, len); }
                        catch (android.system.ErrnoException e) { throw new java.io.IOException(e); }
                    }
                };
                try {
                    HeadUnitExplorer exp = new HeadUnitExplorer();
                    exp.connect(in, out, this::log);
                    explorer = exp;
                    updateAllTabs();
                } finally { in.close(); pfd.close(); probeRunning = false; }
            } catch (Exception e) {
                log("USB error: " + e.getMessage());
                explorer = null;
                updateProbeStatus("Error: " + e.getMessage());
                probeRunning = false;
            }
        }).start();
    }

    private void log(String msg) {
        Log.i("NftpProbe", msg);
        synchronized (logBuffer) { logBuffer.append(msg).append('\n'); }
        if (activeTab == tabLog) refreshLog();
    }

    private static String formatSize(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format("%.1f KB", bytes / 1024.0);
        if (bytes < 1024L * 1024 * 1024) return String.format("%.1f MB", bytes / (1024.0 * 1024));
        return String.format("%.1f GB", bytes / (1024.0 * 1024 * 1024));
    }
}
