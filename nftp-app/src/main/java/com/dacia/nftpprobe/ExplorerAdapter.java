package com.dacia.nftpprobe;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.recyclerview.widget.RecyclerView;

import com.dacia.nftp.HeadUnitExplorer;

import java.util.List;

public class ExplorerAdapter extends RecyclerView.Adapter<ExplorerAdapter.ViewHolder> {

    public interface OnItemClick {
        void onClick(HeadUnitExplorer.FileEntry entry);
    }

    private final List<HeadUnitExplorer.FileEntry> entries;
    private final OnItemClick listener;

    public ExplorerAdapter(List<HeadUnitExplorer.FileEntry> entries, OnItemClick listener) {
        this.entries = entries;
        this.listener = listener;
    }

    static class ViewHolder extends RecyclerView.ViewHolder {
        TextView txtIcon, txtName;
        ViewHolder(View v) {
            super(v);
            txtIcon = v.findViewById(R.id.txtIcon);
            txtName = v.findViewById(R.id.txtName);
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
        holder.itemView.setOnClickListener(v -> listener.onClick(entry));
    }

    @Override
    public int getItemCount() { return entries.size(); }
}
