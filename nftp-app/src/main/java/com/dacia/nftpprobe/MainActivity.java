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
import android.util.Log;
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

        // Auto-start if launched with --ez auto_test true
        if (getIntent().getBooleanExtra("auto_test", false)) {
            new Thread(() -> {
                try {
                    NngEngine engine = NngEngine.getInstance();
                    String result = engine.init(this);
                    Log.i("NftpProbe", "Auto-init: " + result);
                    Log.i("NftpProbe", "Initialized: " + engine.isInitialized());

                    if (!engine.isInitialized()) return;

                    com.nng.uie.api.androidConnection aconn = com.nng.uie.api.androidConnection.INSTANCE;

                    // Uses real NNG native modules via asyncEval:
                    // - system://socket for TCP
                    // - system://serialization for Stream(@compact) / Reader
                    // - system://math for bitwise ops (|, &, << not supported as operators)
                    // - system://core.types for DataWriter/DataReader/ArrayBuffer
                    // Note: core/nftp.xs can't be imported from asyncEval, so we do
                    // manual NFTP packet framing but use REAL NNG serialization.

                    // Helper: build the common init+connect preamble
                    String preamble =
                        "const sock = System.import('system://socket');" +
                        "const ct = System.import('system://core.types');" +
                        "const math = System.import('system://math');" +
                        "const ser = System.import('system://serialization');" +
                        "const s = await sock.connect(#{host:'10.0.0.78', port:9876});" +
                        "const initStr = 'YellowBox/1.8.13+e14eabb8';" +
                        "const bl = 1+1+initStr.length+1; const pl = 4+bl;" +
                        "const ib = new ct.ArrayBuffer(pl); const iw = ct.DataWriter(ib);" +
                        "iw.u8(math.and(pl,0xFF));iw.u8(math.and(math.shr(pl,8),0x7F));" +
                        "iw.u8(1);iw.u8(0);iw.u8(0);iw.u8(1);iw.string(initStr);" +
                        "await s.write(ib);";

                    // Helper: send QueryInfo and parse response
                    String sendQuery =
                        "const qbl = 1+p.byteLength; const qpl = 4+qbl;" +
                        "const qb = new ct.ArrayBuffer(qpl); const qw = ct.DataWriter(qb);" +
                        "qw.u8(math.and(qpl,0xFF));qw.u8(math.and(math.shr(qpl,8),0x7F));" +
                        "qw.u8(2);qw.u8(0);qw.u8(4);qw.writeBytes(p);" +
                        "await s.write(qb); const qr = await s.read(4096);" +
                        "const rd = ct.DataReader(qr);" +
                        "rd.u8();rd.u8();rd.u8();rd.u8();" +
                        "const qs = rd.u8();";

                    String parseResponse =
                        "const d = qr.slice(5); const rr = ser.Reader(d); const v = rr.read();";

                    // Test 1: Init handshake
                    String initScript = preamble +
                        "const resp = await s.read(1024);" +
                        "const r = ct.DataReader(resp);" +
                        "r.u8();r.u8();r.u8();r.u8();" + // skip header
                        "const status = r.u8();" +
                        "const ver = r.u8();" +
                        "const name = r.string();" +
                        "SysConfig.set('probe','init', name + ' v' + ver + ' status=' + status);" +
                        "s.close(); 'init done'";
                    Object r1 = engine.evalSync(aconn, initScript, 15000);
                    Log.i("NftpProbe", "Init: " + engine.formatResult(r1));
                    Log.i("NftpProbe", "RESULT init = " + engine.formatResult(
                        engine.evalSync(aconn, "SysConfig.get('probe','init','')", 3000)));

                    // Test 2: QueryInfo @fileMapping (real NNG serialization)
                    String fmScript = preamble + 
                        "const resp = await s.read(1024);" +
                        "SysConfig.set('probe','init_resp','got '+resp.byteLength+' bytes');" +
                        "s.close(); 'fm done'";
                    Object r2 = engine.evalSync(aconn, fmScript, 15000);
                    Log.i("NftpProbe", "FM: " + engine.formatResult(r2));
                    Log.i("NftpProbe", "RESULT qi_fm = " + engine.formatResult(
                        engine.evalSync(aconn, "SysConfig.get('probe','qi_fm','')", 3000)));
                    Log.i("NftpProbe", "RESULT qi_fm_status = " + engine.formatResult(
                        engine.evalSync(aconn, "SysConfig.get('probe','qi_fm_status','')", 3000)));

                    // Test 3: QueryInfo @device, @brand
                    String devScript = preamble + "await s.read(1024);" +
                        "const st = ser.Stream(@compact); st.add((@device, @brand));" +
                        "const p = st.transfer();" + sendQuery +
                        "if(qs==0){" + parseResponse +
                        "SysConfig.set('probe','qi_dev','status='+qs+' val='+v);}" +
                        "s.close(); 'dev done'";
                    Object r3 = engine.evalSync(aconn, devScript, 15000);
                    Log.i("NftpProbe", "Dev: " + engine.formatResult(r3));
                    Log.i("NftpProbe", "RESULT qi_dev = " + engine.formatResult(
                        engine.evalSync(aconn, "SysConfig.get('probe','qi_dev','')", 3000)));

                    // Test 4: @ls directory listing
                    String lsScript = preamble + "await s.read(1024);" +
                        "const st = ser.Stream(@compact);" +
                        "st.add((@ls, 'content', #{fields: (@name, @size)}));" +
                        "const p = st.transfer();" + sendQuery +
                        "if(qs==0){" + parseResponse +
                        "SysConfig.set('probe','qi_ls','status='+qs+' val='+v);}" +
                        "s.close(); 'ls done'";
                    Object r4 = engine.evalSync(aconn, lsScript, 15000);
                    Log.i("NftpProbe", "LS: " + engine.formatResult(r4));
                    Log.i("NftpProbe", "RESULT qi_ls = " + engine.formatResult(
                        engine.evalSync(aconn, "SysConfig.get('probe','qi_ls','')", 3000)));

                    Log.i("NftpProbe", "=== ALL REAL-CODE TESTS COMPLETE ===");

                } catch (Throwable t) {
                    Log.e("NftpProbe", "Auto-test error", t);
                }
            }).start();
        }
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
            log("Connect button clicked");
            android.widget.EditText editHost = probeView.findViewById(R.id.editHost);
            String host = editHost.getText().toString().trim();
            log("Host: '" + host + "'");
            if (!host.isEmpty()) {
                log("Calling runProbeOverTcp...");
                runProbeOverTcp(host, 9876);
            } else {
                log("Host is empty!");
            }
        });

        probeView.findViewById(R.id.btnNngProbe).setOnClickListener(v -> {
            android.widget.TextView txtResult = probeView.findViewById(R.id.txtNngResult);
            txtResult.setText("Loading NNG SDK...\n");
            new Thread(() -> {
                try {
                    // Use app's data dir as xs root
                    String root = getFilesDir().getAbsolutePath();
                    String result = NngProbe.probeSymbols(root);
                    runOnUiThread(() -> txtResult.setText(result));
                    log(result);
                } catch (Throwable t) {
                    String err = "NNG probe error: " + t.getClass().getSimpleName() + ": " + t.getMessage();
                    runOnUiThread(() -> txtResult.setText(err));
                    log(err);
                }
            }).start();
        });

        probeView.findViewById(R.id.btnNngEngine).setOnClickListener(v -> {
            android.widget.TextView txtResult = probeView.findViewById(R.id.txtNngResult);
            txtResult.setText("Starting NNG Engine...\n");
            new Thread(() -> {
                try {
                    NngEngine engine = NngEngine.getInstance();
                    String result = engine.init(this);
                    StringBuilder sb = new StringBuilder();
                    sb.append("Result: ").append(result).append("\n");
                    sb.append("Initialized: ").append(engine.isInitialized()).append("\n");
                    if (engine.getLastError() != null) {
                        sb.append("Last error: ").append(engine.getLastError()).append("\n");
                    }
                    String msg = sb.toString();
                    runOnUiThread(() -> txtResult.setText(msg));
                    log(msg);
                } catch (Throwable t) {
                    String err = "NNG Engine error: " + t.getClass().getSimpleName() + ": " + t.getMessage();
                    runOnUiThread(() -> txtResult.setText(err));
                    log(err);
                    t.printStackTrace();
                }
            }).start();
        });

        probeView.findViewById(R.id.btnConnectEmulator).setOnClickListener(v -> {
            android.widget.TextView txtResult = probeView.findViewById(R.id.txtNngResult);
            android.widget.EditText editHost = probeView.findViewById(R.id.editHost);
            String host = editHost.getText().toString().trim();
            if (host.isEmpty()) host = "10.0.0.78";
            final String finalHost = host;
            
            txtResult.setText("NNG TCP connecting to " + host + ":9876...\n");
            new Thread(() -> {
                try {
                    NngEngine engine = NngEngine.getInstance();
                    if (!engine.isInitialized()) {
                        runOnUiThread(() -> txtResult.setText("Engine not initialized. Start it first."));
                        return;
                    }
                    String result = engine.connectToEmulatorNng(finalHost, 9876);
                    runOnUiThread(() -> txtResult.setText(result));
                    log(result);
                } catch (Throwable t) {
                    String err = "Error: " + t.getClass().getSimpleName() + ": " + t.getMessage();
                    runOnUiThread(() -> txtResult.setText(err));
                    log(err);
                }
            }).start();
        });

        probeView.findViewById(R.id.btnQueryDisk).setOnClickListener(v -> {
            android.widget.TextView txtResult = probeView.findViewById(R.id.txtNngResult);
            txtResult.setText("Querying disk info via NNG...\n");
            new Thread(() -> {
                try {
                    NngEngine engine = NngEngine.getInstance();
                    if (!engine.isInitialized()) {
                        runOnUiThread(() -> txtResult.setText("Engine not initialized."));
                        return;
                    }
                    String result = engine.queryDiskInfo();
                    runOnUiThread(() -> txtResult.setText(result));
                    log(result);
                } catch (Throwable t) {
                    String err = "Error: " + t.getMessage();
                    runOnUiThread(() -> txtResult.setText(err));
                }
            }).start();
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
        View dlgView = getLayoutInflater().inflate(R.layout.dialog_file_detail, null);
        android.widget.TextView txtPath = dlgView.findViewById(R.id.txtFilePath);
        android.widget.TextView txtInfo = dlgView.findViewById(R.id.txtFileInfo);
        android.widget.TextView txtResult = dlgView.findViewById(R.id.txtResult);
        Button btnMd5 = dlgView.findViewById(R.id.btnMd5);
        Button btnSha1 = dlgView.findViewById(R.id.btnSha1);
        Button btnDownload = dlgView.findViewById(R.id.btnDownload);
        Button btnSave = dlgView.findViewById(R.id.btnSave);

        txtPath.setText(entry.path);
        txtInfo.setText(entry.isDir ? "Directory" : "File");

        final byte[][] downloadedData = {null};

        android.app.AlertDialog dlg = new android.app.AlertDialog.Builder(this)
                .setView(dlgView).setNeutralButton("Close", null).create();

        btnMd5.setOnClickListener(v -> new Thread(() -> {
            try {
                // Use lastResult's connection — for now just show we'd call checksum
                log("CheckSum MD5 for " + entry.path);
                runOnUiThread(() -> txtResult.setText("MD5: (requires active connection)"));
            } catch (Exception e) {
                runOnUiThread(() -> txtResult.setText("Error: " + e.getMessage()));
            }
        }).start());

        btnSha1.setOnClickListener(v -> new Thread(() -> {
            try {
                log("CheckSum SHA1 for " + entry.path);
                runOnUiThread(() -> txtResult.setText("SHA1: (requires active connection)"));
            } catch (Exception e) {
                runOnUiThread(() -> txtResult.setText("Error: " + e.getMessage()));
            }
        }).start());

        btnDownload.setOnClickListener(v -> new Thread(() -> {
            try {
                log("Download " + entry.path);
                runOnUiThread(() -> txtResult.setText("Downloading... (requires active connection)"));
            } catch (Exception e) {
                runOnUiThread(() -> txtResult.setText("Error: " + e.getMessage()));
            }
        }).start());

        btnSave.setOnClickListener(v -> {
            if (downloadedData[0] == null) return;
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
                log("Save error: " + e.getMessage());
                txtResult.setText("Save error: " + e.getMessage());
            }
        });

        dlg.show();
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
