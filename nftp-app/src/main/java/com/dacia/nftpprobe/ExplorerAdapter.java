package com.dacia.nftpprobe;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.recyclerview.widget.RecyclerView;

import com.dacia.nftp.HeadUnitExplorer;

import java.util.ArrayList;
import java.util.List;

public class ExplorerAdapter extends RecyclerView.Adapter<ExplorerAdapter.ViewHolder> {

    public interface OnItemClick {
        void onClick(HeadUnitExplorer.FileEntry entry);
    }

    private List<HeadUnitExplorer.FileEntry> entries;
    private final OnItemClick listener;

    public ExplorerAdapter(List<HeadUnitExplorer.FileEntry> entries, OnItemClick listener) {
        this.entries = new ArrayList<>(entries);
        this.listener = listener;
    }

    public void updateEntries(List<HeadUnitExplorer.FileEntry> newEntries) {
        this.entries = new ArrayList<>(newEntries);
        notifyDataSetChanged();
    }

    static class ViewHolder extends RecyclerView.ViewHolder {
        TextView txtIcon, txtName, txtSize;
        ViewHolder(View v) {
            super(v);
            txtIcon = v.findViewById(R.id.txtIcon);
            txtName = v.findViewById(R.id.txtName);
            txtSize = v.findViewById(R.id.txtSize);
        }
    }

    @Override
    public ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        View v = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_file_entry, parent, false);
        return new ViewHolder(v);
    }

    @Override
    public void onBindViewHolder(ViewHolder holder, int position) {
        HeadUnitExplorer.FileEntry entry = entries.get(position);
        holder.txtIcon.setText(entry.isDir ? "📁" : "📄");
        holder.txtName.setText(entry.name);
        if (entry.isDir || entry.size == 0) {
            holder.txtSize.setText("");
        } else {
            holder.txtSize.setText(formatSize(entry.size));
        }
        holder.itemView.setOnClickListener(v -> listener.onClick(entry));
    }

    @Override
    public int getItemCount() { return entries.size(); }

    private static String formatSize(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format("%.1f KB", bytes / 1024.0);
        if (bytes < 1024L * 1024 * 1024) return String.format("%.1f MB", bytes / (1024.0 * 1024));
        return String.format("%.1f GB", bytes / (1024.0 * 1024 * 1024));
    }
}
