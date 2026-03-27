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
import android.widget.Button;
import android.widget.EditText;
import android.widget.ScrollView;
import android.widget.TextView;

import com.dacia.nftp.NftpProbe;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.net.Socket;

public class MainActivity extends Activity {

    private static final String ACTION_USB_PERMISSION = "com.dacia.nftpprobe.USB_PERMISSION";
    private TextView txtLog;
    private ScrollView scrollView;
    private PendingIntent permissionIntent;
    private volatile boolean probeRunning = false;

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

        txtLog = findViewById(R.id.txtLog);
        scrollView = findViewById(R.id.scrollView);
        EditText editHost = findViewById(R.id.editHost);
        Button btnConnect = findViewById(R.id.btnConnect);

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

        btnConnect.setOnClickListener(v -> {
            String host = editHost.getText().toString().trim();
            if (!host.isEmpty()) {
                runProbeOverTcp(host, 9876);
            }
        });

        handleIntent(getIntent());
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
        if (emuHost != null) {
            runProbeOverTcp(emuHost, 9876);
            return;
        }

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
        new Thread(() -> {
            try (Socket sock = new Socket(host, port)) {
                NftpProbe.run(sock.getInputStream(), sock.getOutputStream(), this::log);
            } catch (Exception e) {
                log("TCP error: " + e.getMessage());
            }
        }).start();
    }

    private void runProbeOverUsb(UsbAccessory accessory) {
        if (probeRunning) {
            log("Probe already running, skipping");
            return;
        }
        probeRunning = true;
        log("Opening USB accessory: " + accessory.getManufacturer() + "/" + accessory.getModel());
        log("  Description: " + accessory.getDescription());
        log("  Version: " + accessory.getVersion());
        log("  URI: " + accessory.getUri());
        UsbManager usb = (UsbManager) getSystemService(USB_SERVICE);
        new Thread(() -> {
            try {
                ParcelFileDescriptor pfd = usb.openAccessory(accessory);
                if (pfd == null) {
                    log("Failed to open accessory");
                    return;
                }
                log("Accessory fd=" + pfd.getFd());
                java.io.FileDescriptor rawFd = pfd.getFileDescriptor();
                log("FileDescriptor valid=" + rawFd.valid());

                // Try reading first to see if head unit sends anything
                FileInputStream in = new FileInputStream(rawFd);
                log("Streams created, checking for incoming data...");

                // Non-blocking check: see if any bytes are available
                try {
                    int avail = in.available();
                    log("Bytes available before Init: " + avail);
                    if (avail > 0) {
                        byte[] pre = new byte[Math.min(avail, 256)];
                        int n = in.read(pre);
                        log("Pre-Init data (" + n + " bytes): " + hexDump(pre, n));
                    }
                } catch (Exception e) {
                    log("available() not supported on USB fd: " + e.getMessage());
                }

                // Use raw POSIX write via Os.write to ensure data reaches USB
                java.io.FileDescriptor writeFd = pfd.getFileDescriptor();
                java.io.OutputStream out = new java.io.OutputStream() {
                    public void write(int b) throws java.io.IOException {
                        write(new byte[]{(byte) b}, 0, 1);
                    }
                    public void write(byte[] b, int off, int len) throws java.io.IOException {
                        try {
                            android.system.Os.write(writeFd, b, off, len);
                        } catch (android.system.ErrnoException e) {
                            throw new java.io.IOException(e);
                        }
                    }
                    public void flush() {} // Os.write is unbuffered
                };

                try {
                    NftpProbe.run(in, out, this::log);
                } finally {
                    in.close();
                    pfd.close();
                    probeRunning = false;
                }
            } catch (Exception e) {
                log("USB error: " + e.getClass().getName() + ": " + e.getMessage());
                probeRunning = false;
            }
        }).start();
    }

    private void log(String msg) {
        android.util.Log.i("NftpProbe", msg);
        runOnUiThread(() -> {
            txtLog.append(msg + "\n");
            scrollView.post(() -> scrollView.fullScroll(ScrollView.FOCUS_DOWN));
        });
    }

    private static String hexDump(byte[] data, int len) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < len; i++) {
            if (i > 0) sb.append(' ');
            sb.append(String.format("%02x", data[i] & 0xFF));
        }
        return sb.toString();
    }
}
