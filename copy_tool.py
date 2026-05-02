# -*- coding: utf-8 -*-
# 資料夾批量複製工具 - GUI版
import shutil, os, datetime, sys, threading
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

class CopyToolApp:
    def __init__(self, root):
        self.root = root
        self.root.title("資料夾批量複製工具")
        self.root.geometry("700x520")
        self.root.resizable(False, False)
        self.copying = False
        self.stop_flag = False

        # 來源路徑
        frame_src = ttk.LabelFrame(root, text="來源路徑 (複製從哪裡)", padding=10)
        frame_src.pack(fill='x', padx=15, pady=(15,5))

        self.src_var = tk.StringVar()
        ttk.Entry(frame_src, textvariable=self.src_var, width=70).pack(side='left', fill='x', expand=True)
        ttk.Button(frame_src, text="瀏覽...", command=self.browse_src).pack(side='right', padx=(10,0))

        # 目標路徑
        frame_dst = ttk.LabelFrame(root, text="目標路徑 (複製到哪裡)", padding=10)
        frame_dst.pack(fill='x', padx=15, pady=5)

        self.dst_var = tk.StringVar()
        ttk.Entry(frame_dst, textvariable=self.dst_var, width=70).pack(side='left', fill='x', expand=True)
        ttk.Button(frame_dst, text="瀏覽...", command=self.browse_dst).pack(side='right', padx=(10,0))

        # 按鈕列
        frame_btn = ttk.Frame(root)
        frame_btn.pack(fill='x', padx=15, pady=10)

        self.btn_start = ttk.Button(frame_btn, text="開始複製", command=self.start_copy)
        self.btn_start.pack(side='left')

        self.btn_stop = ttk.Button(frame_btn, text="停止", command=self.stop_copy, state='disabled')
        self.btn_stop.pack(side='left', padx=(10,0))

        self.status_label = ttk.Label(frame_btn, text="就緒", foreground="gray")
        self.status_label.pack(side='right')

        # 進度條
        self.progress = ttk.Progressbar(root, mode='determinate')
        self.progress.pack(fill='x', padx=15, pady=(0,5))

        self.progress_label = ttk.Label(root, text="")
        self.progress_label.pack(fill='x', padx=15)

        # 日誌
        frame_log = ttk.LabelFrame(root, text="複製日誌", padding=5)
        frame_log.pack(fill='both', expand=True, padx=15, pady=(5,15))

        self.log_text = tk.Text(frame_log, height=12, font=("Consolas", 9))
        scrollbar = ttk.Scrollbar(frame_log, command=self.log_text.yview)
        self.log_text.configure(yscrollcommand=scrollbar.set)
        scrollbar.pack(side='right', fill='y')
        self.log_text.pack(fill='both', expand=True)

    def browse_src(self):
        path = filedialog.askdirectory(title="選擇來源資料夾")
        if path:
            self.src_var.set(path)

    def browse_dst(self):
        path = filedialog.askdirectory(title="選擇目標資料夾")
        if path:
            self.dst_var.set(path)

    def log(self, msg):
        ts = datetime.datetime.now().strftime('%H:%M:%S')
        self.log_text.insert('end', f"[{ts}] {msg}\n")
        self.log_text.see('end')

    def start_copy(self):
        src = self.src_var.get().strip().strip('"')
        dst = self.dst_var.get().strip().strip('"')

        if not src or not dst:
            messagebox.showwarning("提示", "請先設定來源和目標路徑")
            return
        if not os.path.exists(src):
            messagebox.showerror("錯誤", f"來源路徑不存在:\n{src}")
            return

        self.copying = True
        self.stop_flag = False
        self.btn_start.config(state='disabled')
        self.btn_stop.config(state='normal')
        self.status_label.config(text="複製中...", foreground="blue")
        self.log_text.delete('1.0', 'end')

        thread = threading.Thread(target=self.copy_worker, args=(src, dst), daemon=True)
        thread.start()

    def stop_copy(self):
        self.stop_flag = True
        self.btn_stop.config(state='disabled')
        self.status_label.config(text="正在停止...", foreground="orange")

    def copy_worker(self, src, dst):
        try:
            os.makedirs(dst, exist_ok=True)
            all_items = sorted(os.listdir(src))
            done = set(os.listdir(dst))
            todo = [x for x in all_items if x not in done]
            total = len(all_items)

            self.root.after(0, lambda: self.log(f"來源: {src}"))
            self.root.after(0, lambda: self.log(f"目標: {dst}"))
            self.root.after(0, lambda: self.log(f"總共: {total} | 已完成: {len(done)} | 剩餘: {len(todo)}"))
            self.root.after(0, lambda: self.log("-" * 50))
            self.root.after(0, lambda: self.progress.configure(maximum=total, value=len(done)))

            if not todo:
                self.root.after(0, lambda: self.log("全部已複製完成!"))
                self.root.after(0, self.copy_finished)
                return

            copied = 0
            failed = 0

            for i, name in enumerate(todo):
                if self.stop_flag:
                    msg = f"已停止。本次複製: {copied} | 失敗: {failed}"
                    self.root.after(0, lambda m=msg: self.log(m))
                    break

                s = os.path.join(src, name)
                d = os.path.join(dst, name)
                num = len(done) + copied + failed + 1

                self.root.after(0, lambda n=name, nu=num: (
                    self.status_label.config(text=f"({nu}/{total}) {n}"),
                    self.progress_label.config(text=f"{nu}/{total} ({round(nu/total*100,1)}%)")
                ))

                try:
                    if os.path.isdir(s):
                        shutil.copytree(s, d)
                    else:
                        shutil.copy2(s, d)
                    copied += 1
                    cur = len(done) + copied + failed
                    self.root.after(0, lambda n=name, c=cur: (
                        self.log(f"OK ({c}/{total}) {n}"),
                        self.progress.configure(value=c)
                    ))
                except Exception as e:
                    failed += 1
                    cur = len(done) + copied + failed
                    self.root.after(0, lambda n=name, err=str(e), c=cur: (
                        self.log(f"FAIL ({c}/{total}) {n}: {err}"),
                        self.progress.configure(value=c)
                    ))

            if not self.stop_flag:
                msg = f"完成! 本次複製: {copied} | 跳過: {len(done)} | 失敗: {failed} | 總共: {total}"
                self.root.after(0, lambda m=msg: self.log(m))

        except Exception as e:
            self.root.after(0, lambda: self.log(f"錯誤: {e}"))

        self.root.after(0, self.copy_finished)

    def copy_finished(self):
        self.copying = False
        self.stop_flag = False
        self.btn_start.config(state='normal')
        self.btn_stop.config(state='disabled')
        self.status_label.config(text="完成", foreground="green")

if __name__ == '__main__':
    root = tk.Tk()
    app = CopyToolApp(root)
    root.mainloop()
