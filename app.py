import os
import queue
import subprocess
import sys
import threading
import tkinter as tk
from tkinter import filedialog, scrolledtext

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import injector

APP_NAME = 'ProgressMOD'


def base_dir():
    try:
        d = os.path.dirname(os.path.abspath(sys.argv[0]))
        probe = os.path.join(d, '.__writetest__')
        with open(probe, 'w') as f:
            f.write('x')
        os.remove(probe)
        return d
    except Exception:
        return HERE


LASTDIR = os.path.join(base_dir(), 'lastdir.txt')
try:
    import tempfile
    LASTDIR = os.path.join(tempfile.gettempdir(), 'ProgressMOD-lastdir.txt')
except Exception:
    pass

STEAM_CANDS = [
    r'C:\Program Files (x86)\Steam\steamapps\common\Progressbar95',
    r'C:\Program Files\Steam\steamapps\common\Progressbar95',
]


def looks_like_game(d):
    return (
        bool(d)
        and os.path.isfile(os.path.join(d, 'Progressbar95.exe'))
        and os.path.isfile(os.path.join(d, 'Resources', 'resource.car'))
    )


def is_patched(game):
    try:
        import hashlib
        import json

        man_path = os.path.join(game, 'v1_manifest.json')
        if not (
            os.path.isfile(man_path)
            and os.path.isfile(os.path.join(game, 'main.lua'))
            and os.path.isfile(os.path.join(game, 'patched_main.lu'))
        ):
            return False

        with open(man_path) as f:
            man = json.load(f)

        if man.get('mod') != injector.MOD_ID:
            return False

        h = hashlib.sha256()
        with open(os.path.join(game, 'patched_main.lu'), 'rb') as f:
            for blk in iter(lambda: f.read(65536), b''):
                h.update(blk)
        if h.hexdigest() != man.get('patched_main_sha256'):
            return False

        car_path = os.path.join(game, 'Resources', 'resource.car')
        want_car = man.get('car_sha256')
        if want_car and os.path.isfile(car_path):
            hc = hashlib.sha256()
            with open(car_path, 'rb') as f:
                for blk in iter(lambda: f.read(65536), b''):
                    hc.update(blk)
            if hc.hexdigest() != want_car:
                return False

        orig_path = os.path.join(game, 'orig_main.lu')
        want_orig = man.get('orig_main_sha256')
        if want_orig and os.path.isfile(orig_path):
            ho = hashlib.sha256()
            with open(orig_path, 'rb') as f:
                for blk in iter(lambda: f.read(65536), b''):
                    ho.update(blk)
            if ho.hexdigest() != want_orig:
                return False

        with open(os.path.join(game, 'Resources', 'international', 'en', 'strings.xml'), 'rb') as f:
            if b"name='GameModealphabeth'" not in f.read():
                return False

        return True
    except Exception:
        return False


class App:
    def __init__(self, root):
        self.root = root
        root.title(APP_NAME)
        root.geometry('720x480')
        self.q = queue.Queue()

        top = tk.Frame(root)
        top.pack(fill='x', padx=8, pady=8)

        tk.Label(top, text='Game folder:').pack(side='left')
        self.entry = tk.Entry(top, width=70)
        self.entry.pack(side='left', fill='x', expand=True, padx=6)
        tk.Button(top, text='Browse...', width=12, command=self.browse).pack(side='left')

        btns = tk.Frame(root)
        btns.pack(fill='x', padx=8)
        font = ('Segoe UI', 10)

        self.b_inject = tk.Button(
            btns, text='Inject', width=12, font=font, command=lambda: self.run('apply')
        )
        self.b_inject.pack(side='left', padx=4)

        tk.Button(
            btns, text='Revert', width=12, font=font, command=lambda: self.run('restore')
        ).pack(side='left', padx=4)

        tk.Button(btns, text='Play', width=12, font=font, command=self.open_game).pack(
            side='left', padx=4
        )

        self.patched_var = tk.StringVar(value='')
        tk.Label(btns, textvariable=self.patched_var, fg='#7bd88f').pack(side='right', padx=4)

        self.log = scrolledtext.ScrolledText(root, state='disabled', font=('Consolas', 9))
        self.log.pack(fill='both', expand=True, padx=8, pady=8)

        d0 = ''
        try:
            if os.path.isfile(LASTDIR):
                with open(LASTDIR) as f:
                    d0 = f.read().strip()
        except Exception:
            pass

        if not looks_like_game(d0):
            for c in STEAM_CANDS:
                if looks_like_game(c):
                    d0 = c
                    break

        if d0:
            self.entry.insert(0, d0)

        self.entry.bind('<KeyRelease>', lambda _e: self.refresh_state())
        self.entry.bind('<FocusOut>', lambda _e: self.refresh_state())
        self.refresh_state()

    def refresh_state(self):
        def _do():
            try:
                ok = is_patched(self.entry.get().strip().strip('"'))
            except Exception:
                ok = False
            self.b_inject.configure(state='disabled' if ok else 'normal')
            self.patched_var.set('PATCHED' if ok else '')

        self.root.after(0, _do)

    def say(self, msg):
        self.log.configure(state='normal')
        self.log.insert('end', msg + '\n')
        self.log.see('end')
        self.log.configure(state='disabled')

    def game(self):
        d = self.entry.get().strip().strip('"')
        try:
            with open(LASTDIR, 'w') as f:
                f.write(d)
        except Exception:
            pass
        return os.path.abspath(d)

    def browse(self):
        d = filedialog.askdirectory(title='Progressbar95 folder (with Progressbar95.exe)')
        if d:
            self.entry.delete(0, 'end')
            self.entry.insert(0, d)
            self.refresh_state()

    def run(self, cmd):
        g = self.game()
        if not looks_like_game(g):
            self.say('ERROR: bad folder. Expected Progressbar95.exe + Resources\\resource.car in:\n  ' + g)
            return

        self.say('%s in %s' % (cmd, g))
        th = threading.Thread(target=self._worker, args=(cmd, g), daemon=True)
        self._th = th
        th.start()
        self.root.after(100, self._pump)

    def _worker(self, cmd, game):
        import io

        buf = io.StringIO()
        old = sys.stdout
        sys.stdout = buf
        try:
            fn = {
                'apply': injector.cmd_apply,
                'restore': injector.cmd_restore,
                'status': injector.cmd_status,
            }[cmd]
            try:
                res = fn(game)
                if res and not res.startswith('OK '):
                    print(res)
            except Exception as e:
                print('ERROR: %s' % e)
        finally:
            sys.stdout = old

        self.q.put(buf.getvalue())

    def _pump(self):
        try:
            while True:
                self.say(self.q.get_nowait().rstrip('\n'))
        except queue.Empty:
            pass

        th = getattr(self, '_th', None)
        if th is not None and th.is_alive():
            self.root.after(200, self._pump)
        else:
            self.refresh_state()

    def open_game(self):
        g = self.game()
        exe = os.path.join(g, 'Progressbar95.exe')
        if not os.path.isfile(exe):
            self.say('ERROR: Progressbar95.exe not found in ' + g)
            return

        try:
            subprocess.run(
                ['taskkill', '/F', '/IM', 'Progressbar95.exe'],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception:
            pass

        try:
            subprocess.Popen([exe], cwd=g)
            self.say('Game launched.')
        except Exception as e:
            self.say('ERROR launching: %s' % e)


if __name__ == '__main__':
    root = tk.Tk()
    App(root)
    root.mainloop()