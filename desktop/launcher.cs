using System;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Reflection;
using System.Threading;
using System.Diagnostics;

namespace MampirAdmin
{
    class Program
    {
        private static HttpListener listener;
        private static string webRoot;
        private static int port = 8088;
        private static bool isRunning = true;

        [STAThread]
        static void Main(string[] args)
        {
            webRoot = EnsureWebAssetsExtracted();
            if (string.IsNullOrEmpty(webRoot) || !Directory.Exists(webRoot))
            {
                return;
            }

            // Start HTTP listener on free local port
            int attempts = 0;
            while (attempts < 25)
            {
                try
                {
                    listener = new HttpListener();
                    listener.Prefixes.Add("http://127.0.0.1:" + port + "/");
                    listener.Start();
                    break;
                }
                catch
                {
                    port++;
                    attempts++;
                }
            }

            if (listener == null || !listener.IsListening)
            {
                return;
            }

            Thread serverThread = new Thread(ServerLoop);
            serverThread.IsBackground = true;
            serverThread.Start();

            string url = "http://127.0.0.1:" + port + "/";
            Process appProc = LaunchAppWindow(url);

            if (appProc != null)
            {
                appProc.WaitForExit();
            }
            else
            {
                while (isRunning)
                {
                    Thread.Sleep(1000);
                }
            }

            try { isRunning = false; listener.Stop(); } catch { }
        }

        private static string EnsureWebAssetsExtracted()
        {
            try
            {
                Assembly asm = Assembly.GetExecutingAssembly();
                using (Stream resStream = asm.GetManifestResourceStream("web_bundle.zip"))
                {
                    if (resStream == null)
                    {
                        // Fallback for local dev folder if resource not embedded
                        string localDir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, @"build\web");
                        return Directory.Exists(localDir) ? localDir : null;
                    }

                    string appData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                    string targetDir = Path.Combine(appData, "MampirAdmin", "web");
                    string versionFile = Path.Combine(appData, "MampirAdmin", ".version");
                    string expectedVersion = "1.0.4_" + resStream.Length.ToString();

                    if (Directory.Exists(targetDir) && File.Exists(versionFile))
                    {
                        string currentVersion = File.ReadAllText(versionFile).Trim();
                        if (currentVersion == expectedVersion && File.Exists(Path.Combine(targetDir, "index.html")))
                        {
                            return targetDir;
                        }
                    }

                    if (Directory.Exists(targetDir))
                    {
                        try { Directory.Delete(targetDir, true); } catch { }
                    }
                    Directory.CreateDirectory(targetDir);

                    using (ZipArchive archive = new ZipArchive(resStream, ZipArchiveMode.Read))
                    {
                        foreach (ZipArchiveEntry entry in archive.Entries)
                        {
                            if (string.IsNullOrEmpty(entry.Name))
                            {
                                continue;
                            }
                            string destPath = Path.GetFullPath(Path.Combine(targetDir, entry.FullName));
                            if (!destPath.StartsWith(Path.GetFullPath(targetDir), StringComparison.OrdinalIgnoreCase))
                            {
                                continue;
                            }
                            string parentDir = Path.GetDirectoryName(destPath);
                            if (!string.IsNullOrEmpty(parentDir) && !Directory.Exists(parentDir))
                            {
                                Directory.CreateDirectory(parentDir);
                            }
                            using (Stream entryStream = entry.Open())
                            using (FileStream fs = File.Create(destPath))
                            {
                                entryStream.CopyTo(fs);
                            }
                        }
                    }

                    File.WriteAllText(versionFile, expectedVersion);
                    return targetDir;
                }
            }
            catch
            {
                return null;
            }
        }

        private static Process LaunchAppWindow(string url)
        {
            string appData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string profileDir = Path.Combine(appData, "MampirAdmin", "profile");
            if (!Directory.Exists(profileDir))
            {
                try { Directory.CreateDirectory(profileDir); } catch { }
            }

            string[] browsers = new string[]
            {
                @"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
                @"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
                @"C:\Program Files\Google\Chrome\Application\chrome.exe",
                @"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
            };

            foreach (string b in browsers)
            {
                if (File.Exists(b))
                {
                    try
                    {
                        ProcessStartInfo psi = new ProcessStartInfo();
                        psi.FileName = b;
                        psi.Arguments = "--app=" + url + " --window-size=1200,800 --user-data-dir=\"" + profileDir + "\" --no-first-run --no-default-browser-check";
                        psi.UseShellExecute = false;
                        return Process.Start(psi);
                    }
                    catch { }
                }
            }

            try
            {
                return Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
            }
            catch { }
            return null;
        }

        private static void ServerLoop()
        {
            while (isRunning && listener != null && listener.IsListening)
            {
                try
                {
                    HttpListenerContext ctx = listener.GetContext();
                    ThreadPool.QueueUserWorkItem((state) => HandleRequest(ctx));
                }
                catch
                {
                    break;
                }
            }
        }

        private static void HandleRequest(HttpListenerContext ctx)
        {
            try
            {
                string rawUrl = ctx.Request.Url.AbsolutePath;
                if (string.IsNullOrEmpty(rawUrl) || rawUrl == "/")
                {
                    rawUrl = "/index.html";
                }
                string relPath = rawUrl.TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
                string filePath = Path.Combine(webRoot, relPath);

                if (!File.Exists(filePath))
                {
                    filePath = Path.Combine(webRoot, "index.html");
                }

                if (File.Exists(filePath))
                {
                    byte[] bytes = File.ReadAllBytes(filePath);
                    string ext = Path.GetExtension(filePath).ToLowerInvariant();
                    string mime = GetMimeType(ext);

                    ctx.Response.ContentType = mime;
                    ctx.Response.ContentLength64 = bytes.Length;
                    ctx.Response.Headers.Add("Access-Control-Allow-Origin", "*");
                    ctx.Response.OutputStream.Write(bytes, 0, bytes.Length);
                    ctx.Response.Close();
                    return;
                }

                ctx.Response.StatusCode = 404;
                ctx.Response.Close();
            }
            catch
            {
                try { ctx.Response.Close(); } catch { }
            }
        }

        private static string GetMimeType(string ext)
        {
            switch (ext)
            {
                case ".html": return "text/html; charset=utf-8";
                case ".js": case ".mjs": return "application/javascript; charset=utf-8";
                case ".css": return "text/css; charset=utf-8";
                case ".json": return "application/json";
                case ".png": return "image/png";
                case ".jpg": case ".jpeg": return "image/jpeg";
                case ".svg": return "image/svg+xml";
                case ".ico": return "image/x-icon";
                case ".wasm": return "application/wasm";
                case ".otf": return "font/otf";
                case ".ttf": return "font/ttf";
                case ".woff": return "font/woff";
                case ".woff2": return "font/woff2";
                default: return "application/octet-stream";
            }
        }
    }
}
