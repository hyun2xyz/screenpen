"""
ScreenPen for Windows - Lightweight Transparent Overlay Screen Annotation Tool
Runs natively on Windows 10/11 using standard Python with Tkinter.
Supports Pen, Highlighter, Eraser, Spotlight, Clear, Undo, and Keyboard Hotkeys.
"""

import sys
import os
import tkinter as tk

class ScreenPenWindows:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("ScreenPen Overlay")
        
        # Transparent, borderless, always on top, full screen
        self.root.attributes("-fullscreen", True)
        self.root.attributes("-topmost", True)
        self.root.attributes("-alpha", 0.0) # start transparent/invisible
        
        # Windows-specific transparent color keying
        self.trans_color = "#000001"
        try:
            self.root.wm_attributes("-transparentcolor", self.trans_color)
        except Exception:
            pass

        self.screen_width = self.root.winfo_screenwidth()
        self.screen_height = self.root.winfo_screenheight()

        # Canvas for drawing
        self.canvas = tk.Canvas(
            self.root,
            width=self.screen_width,
            height=self.screen_height,
            bg=self.trans_color,
            highlightthickness=0,
            cursor="crosshair"
        )
        self.canvas.pack(fill=tk.BOTH, expand=True)

        # Drawing state
        self.current_tool = "pen"  # pen, highlighter, eraser, spotlight
        self.pen_color = "#ff291f"  # ink red
        self.highlighter_color = "#ffdc1e"  # yellow
        self.pen_width = 4
        self.highlighter_width = 18
        self.eraser_radius = 24
        self.is_active = False

        self.last_x = None
        self.last_y = None
        self.strokes = []  # list of stroke item IDs for undo
        self.current_stroke_items = []
        self.spotlight_item = None

        # Bindings
        self.canvas.bind("<Button-1>", self.on_mouse_down)
        self.canvas.bind("<B1-Motion>", self.on_mouse_drag)
        self.canvas.bind("<ButtonRelease-1>", self.on_mouse_up)
        self.canvas.bind("<Motion>", self.on_mouse_move)
        self.canvas.bind("<Button-3>", lambda e: self.deactivate()) # Right click exits

        # Key bindings on root
        self.root.bind("<Escape>", lambda e: self.deactivate())
        self.root.bind("<Control-Alt-Key-1>", lambda e: self.activate_tool("pen"))
        self.root.bind("<Control-Alt-Key-2>", lambda e: self.activate_tool("highlighter"))
        self.root.bind("<Control-Alt-Key-3>", lambda e: self.activate_tool("spotlight"))
        self.root.bind("<Control-Alt-Key-5>", lambda e: self.activate_tool("eraser"))
        self.root.bind("<Control-Alt-grave>", lambda e: self.clear_all())
        self.root.bind("<Control-z>", lambda e: self.undo())
        self.root.bind("<Control-Z>", lambda e: self.undo())

        # Floating Toolbar Window
        self.setup_toolbar()

    def setup_toolbar(self):
        self.toolbar = tk.Toplevel(self.root)
        self.toolbar.title("ScreenPen Toolbar")
        self.toolbar.attributes("-topmost", True)
        self.toolbar.geometry(f"540x58+{int(self.screen_width/2 - 270)}+{self.screen_height - 90}")
        self.toolbar.configure(bg="#1a1c23")
        self.toolbar.overrideredirect(True)

        self.toolbar.bind("<ButtonPress-1>", self.start_move_toolbar)
        self.toolbar.bind("<B1-Motion>", self.do_move_toolbar)

        f = tk.Frame(self.toolbar, bg="#1a1c23", padx=6, pady=6)
        f.pack(fill=tk.BOTH, expand=True)

        btn_font = ("Segoe UI", 9, "bold")

        self.btn_pen = tk.Button(f, text="🖊 펜 (Ctrl+Alt+1)", font=btn_font, bg="#ff291f", fg="white",
                                 relief="flat", padx=8, pady=4, command=lambda: self.activate_tool("pen"))
        self.btn_pen.pack(side=tk.LEFT, padx=3)

        self.btn_hl = tk.Button(f, text="🖍 형광펜 (Ctrl+Alt+2)", font=btn_font, bg="#2a2d3a", fg="#ffdc1e",
                                relief="flat", padx=8, pady=4, command=lambda: self.activate_tool("highlighter"))
        self.btn_hl.pack(side=tk.LEFT, padx=3)

        self.btn_eraser = tk.Button(f, text="🧹 지우개 (Ctrl+Alt+5)", font=btn_font, bg="#2a2d3a", fg="white",
                                    relief="flat", padx=8, pady=4, command=lambda: self.activate_tool("eraser"))
        self.btn_eraser.pack(side=tk.LEFT, padx=3)

        self.btn_spotlight = tk.Button(f, text="🔦 스포트 (Ctrl+Alt+3)", font=btn_font, bg="#2a2d3a", fg="white",
                                       relief="flat", padx=8, pady=4, command=lambda: self.activate_tool("spotlight"))
        self.btn_spotlight.pack(side=tk.LEFT, padx=3)

        self.btn_undo = tk.Button(f, text="↩", font=btn_font, bg="#2a2d3a", fg="white",
                                  relief="flat", padx=6, pady=4, command=self.undo)
        self.btn_undo.pack(side=tk.LEFT, padx=2)

        self.btn_clear = tk.Button(f, text="🗑 전체삭제", font=btn_font, bg="#2a2d3a", fg="#ff6b6b",
                                   relief="flat", padx=6, pady=4, command=self.clear_all)
        self.btn_clear.pack(side=tk.LEFT, padx=2)

        self.btn_exit = tk.Button(f, text="✕", font=btn_font, bg="#e74c3c", fg="white",
                                  relief="flat", padx=8, pady=4, command=self.quit_app)
        self.btn_exit.pack(side=tk.RIGHT, padx=3)

    def start_move_toolbar(self, event):
        self._tb_x = event.x
        self._tb_y = event.y

    def do_move_toolbar(self, event):
        x = self.toolbar.winfo_x() + (event.x - self._tb_x)
        y = self.toolbar.winfo_y() + (event.y - self._tb_y)
        self.toolbar.geometry(f"+{x}+{y}")

    def activate_tool(self, tool):
        self.current_tool = tool
        self.is_active = True
        self.root.attributes("-alpha", 1.0)
        self.root.lift()
        self.toolbar.lift()

        for b, name, default_color in [
            (self.btn_pen, "pen", "#ff291f"),
            (self.btn_hl, "highlighter", "#ffdc1e"),
            (self.btn_eraser, "eraser", "#00cec9"),
            (self.btn_spotlight, "spotlight", "#feca57")
        ]:
            if self.current_tool == name:
                b.configure(bg=default_color, fg="#111" if name in ["highlighter", "spotlight"] else "white")
            else:
                b.configure(bg="#2a2d3a", fg="white" if name != "highlighter" else "#ffdc1e")

        if tool == "spotlight":
            self.canvas.config(cursor="none")
        else:
            self.canvas.config(cursor="crosshair")

    def deactivate(self):
        self.is_active = False
        if self.spotlight_item:
            self.canvas.delete(self.spotlight_item)
            self.spotlight_item = None
        self.root.attributes("-alpha", 0.0)

    def on_mouse_down(self, event):
        if not self.is_active:
            return
        self.last_x = event.x
        self.last_y = event.y
        self.current_stroke_items = []

        if self.current_tool == "eraser":
            self.erase_at(event.x, event.y)

    def on_mouse_drag(self, event):
        if not self.is_active:
            return
        if self.last_x is None:
            self.last_x = event.x
            self.last_y = event.y
            return

        if self.current_tool == "pen":
            line = self.canvas.create_line(
                self.last_x, self.last_y, event.x, event.y,
                fill=self.pen_color, width=self.pen_width,
                capstyle=tk.ROUND, joinstyle=tk.ROUND, smooth=True
            )
            self.current_stroke_items.append(line)
        elif self.current_tool == "highlighter":
            line = self.canvas.create_line(
                self.last_x, self.last_y, event.x, event.y,
                fill=self.highlighter_color, width=self.highlighter_width,
                capstyle=tk.ROUND, joinstyle=tk.ROUND, smooth=True
            )
            self.current_stroke_items.append(line)
        elif self.current_tool == "eraser":
            self.erase_at(event.x, event.y)

        self.last_x = event.x
        self.last_y = event.y

    def on_mouse_up(self, event):
        if self.current_stroke_items:
            self.strokes.append(self.current_stroke_items)
            self.current_stroke_items = []
        self.last_x = None
        self.last_y = None

    def on_mouse_move(self, event):
        if self.current_tool == "spotlight" and self.is_active:
            if self.spotlight_item:
                self.canvas.delete(self.spotlight_item)
            r = 75
            self.spotlight_item = self.canvas.create_oval(
                event.x - r, event.y - r, event.x + r, event.y + r,
                outline="#feca57", width=3
            )

    def erase_at(self, x, y):
        r = self.eraser_radius
        overlapping = self.canvas.find_overlapping(x - r, y - r, x + r, y + r)
        for item in overlapping:
            if item != self.spotlight_item:
                self.canvas.delete(item)
                for stroke in self.strokes:
                    if item in stroke:
                        stroke.remove(item)

    def undo(self):
        if self.strokes:
            last_stroke = self.strokes.pop()
            for item in last_stroke:
                self.canvas.delete(item)

    def clear_all(self):
        self.canvas.delete("all")
        self.strokes.clear()
        self.spotlight_item = None

    def quit_app(self):
        self.root.destroy()
        sys.exit(0)

    def run(self):
        self.activate_tool("pen")
        self.root.mainloop()

if __name__ == "__main__":
    app = ScreenPenWindows()
    app.run()
