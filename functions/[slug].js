// functions/[slug].js
export async function onRequestGet(context) {
    const { params, env } = context;
    const slug = params.slug;
    
    // Validate slug format (8 hex chars)
    if (!/^[a-f0-9]{8}$/i.test(slug)) {
        return new Response(getMainHTML(), {
            status: 404,
            headers: { 'Content-Type': 'text/html' }
        });
    }
    
    try {
        // Lấy data từ D1
        const stmt = env.DB.prepare('SELECT data FROM benchmarks WHERE slug = ?');
        const result = await stmt.bind(slug).first();
        
        if (!result) {
            return new Response(getMainHTML(), {
                status: 404,
                headers: { 'Content-Type': 'text/html' }
            });
        }
        
        // Update access count (fire-and-forget)
        const updateStmt = env.DB.prepare(`
            UPDATE benchmarks 
            SET accessed_count = accessed_count + 1, last_accessed = ? 
            WHERE slug = ?
        `);
        // Don't await này để không block response
        updateStmt.bind(new Date().toISOString(), slug).run().catch(console.error);
        
        // Return HTML với embedded data
        return new Response(getMainHTML(result.data), {
            headers: { 
                'Content-Type': 'text/html',
                'Cache-Control': 'public, max-age=3600' // Cache 1 hour
            }
        });
        
    } catch (error) {
        console.error('Database error:', error);
        return new Response(getMainHTML(), {
            status: 500,
            headers: { 'Content-Type': 'text/html' }
        });
    }
}

function getMainHTML(data = null) {
    // Escape data để tránh XSS
    const safeData = data ? JSON.stringify(data) : 'null';
    
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${data ? 'Benchmark Results' : 'VPS Benchmark'} - Performance Testing</title>
    <meta name="description" content="VPS server performance benchmark results including CPU, memory, disk I/O and network speed tests.">
    
    <!-- Open Graph cho social sharing -->
    <meta property="og:title" content="${data ? 'VPS Benchmark Results' : 'VPS Benchmark Tool'}">
    <meta property="og:description" content="Comprehensive VPS performance testing results">
    <meta property="og:type" content="website">
    <meta property="og:url" content="https://benchmark.bibica.net">
    
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Courier New', monospace; 
            background: linear-gradient(135deg, #0a0a0a 0%, #1a1a1a 100%); 
            color: #00ff00; 
            padding: 20px; 
            line-height: 1.6; 
            min-height: 100vh;
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto; 
            background: rgba(26,26,26,0.9); 
            padding: 30px; 
            border-radius: 15px; 
            border: 1px solid #333; 
            box-shadow: 0 10px 30px rgba(0,255,0,0.1);
            backdrop-filter: blur(10px);
        }
        .header { 
            text-align: center; 
            margin-bottom: 30px; 
            color: #00ffff; 
        }
        .header h1 { 
            font-size: 2.5em; 
            margin-bottom: 10px; 
            text-shadow: 0 0 10px #00ffff;
        }
        .benchmark-data { 
            background: #000; 
            padding: 25px; 
            border-radius: 10px; 
            overflow-x: auto; 
            border: 1px solid #333; 
            white-space: pre;
            font-size: 14px;
            line-height: 1.4;
            font-family: 'Courier New', monospace;
            color: #ffffff;
        }
        .welcome { 
            text-align: center; 
            padding: 60px 20px;
        }
        .welcome h1 { 
            font-size: 3em; 
            margin-bottom: 20px; 
            text-shadow: 0 0 20px #00ff00;
        }
        .welcome .subtitle { 
            font-size: 1.2em; 
            color: #888; 
            margin-bottom: 30px;
        }
        .command-box { 
            background: #000; 
            padding: 20px; 
            border-radius: 10px; 
            margin: 30px 0; 
            color: #00ffff; 
            font-size: 16px; 
            border: 1px solid #333;
            text-align: center;
        }
        .share-btn {
            background: #00ffff;
            color: #000;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            cursor: pointer;
            font-family: inherit;
            font-weight: bold;
            margin: 10px 5px;
            transition: all 0.3s;
        }
        .share-btn:hover {
            background: #00ff00;
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0,255,255,0.3);
        }
        .footer { 
            text-align: center; 
            margin-top: 30px; 
            color: #888; 
            font-size: 14px; 
        }
        .footer a { 
            color: #00ffff; 
            text-decoration: none; 
            transition: all 0.3s;
        }
        .footer a:hover { 
            text-decoration: underline; 
            text-shadow: 0 0 5px #00ffff;
        }
        @media (max-width: 768px) {
            body { padding: 10px; }
            .container { padding: 20px; }
            .benchmark-data { padding: 15px; font-size: 12px; }
            .header h1 { font-size: 2em; }
            .welcome h1 { font-size: 2em; }
            .command-box { font-size: 14px; padding: 15px; }
        }
    </style>
</head>
<body>
    <div class="container" id="container">
        <!-- Content will be loaded here -->
    </div>

    <script>
        // Server data được inject
        const serverData = ${safeData};
        
        function decodeData() {
            // Ưu tiên server data
            if (serverData && serverData !== null) {
                try {
                    return atob(serverData);
                } catch (e) {
                    console.error('Failed to decode server data:', e);
                    return false;
                }
            }
            
            // Fallback cho backward compatibility với hash URLs
            try {
                const hash = window.location.hash.substring(1);
                if (!hash) return null;
                return atob(hash);
            } catch (e) {
                console.error('Failed to decode hash data:', e);
                return false;
            }
        }

        function processAnsiCodes(text) {
            // Your existing processAnsiCodes function
            text = text
                .replace(/\\[OK\\]/g, '✓')
                .replace(/\\[FAIL\\]/g, '✗');

            // Version info
            text = text.replace(/(Version\\s*:\\s*)(.+)/g, '$1<span style="color: #00ff00;">$2</span>')
                       .replace(/(Usage\\s*:\\s*)(.+)/g, '$1<span style="color: #ff0000;">$2</span>');

            // System info colors
            text = text.replace(/(CPU Model\\s*:\\s*)(.+)/g, '$1<span style="color: #00ffff;">$2</span>')
                       .replace(/(CPU Cores\\s*:\\s*)(.+)/g, '$1<span style="color: #00ffff;">$2</span>')
                       .replace(/(CPU Cache\\s*:\\s*)(.+)/g, '$1<span style="color: #00ffff;">$2</span>')
                       .replace(/(System uptime\\s*:\\s*)(.+)/g, '$1<span style="color: #00ffff;">$2</span>')
                       .replace(/(Load average\\s*:\\s*)(.+)/g, '$1<span style="color: #00ffff;">$2</span>')
                       .replace(/(OS\\s*:\\s*)(.+)/g, '$1<span style="color: #00ffff;">$2</span>')
                       .replace(/(Arch\\s*:\\s*)(.+)/g, '$1<span style="color: #00ffff;">$2</span>')
                       .replace(/(Kernel\\s*:\\s*)(.+)/g, '$1<span style="color: #00ffff;">$2</span>')
                       .replace(/(Virtualization\\s*:\\s*)(.+)/g, '$1<span style="color: #00ffff;">$2</span>');

            // Memory/Disk colors
            text = text.replace(/(Total Disk\\s*:\\s*)([^(]+)(\\([^)]+\\))/g, '$1<span style="color: #ffff00;">$2</span><span style="color: #00ffff;">$3</span>')
                       .replace(/(Total Mem\\s*:\\s*)([^(]+)(\\([^)]+\\))/g, '$1<span style="color: #ffff00;">$2</span><span style="color: #00ffff;">$3</span>')
                       .replace(/(Total Swap\\s*:\\s*)(.+)/g, '$1<span style="color: #00ffff;">$2</span>')
                       .replace(/(TCP CC\\s*:\\s*)(.+)/g, '$1<span style="color: #ffff00;">$2</span>');

            // Status colors
            text = text.replace(/(AES-NI\\s*:\\s*)(✓ Enabled)/g, '$1<span style="color: #00ff00;">$2</span>')
                       .replace(/(AES-NI\\s*:\\s*)(✗ Disabled)/g, '$1<span style="color: #ff0000;">$2</span>')
                       .replace(/(VM-x\\/AMD-V\\s*:\\s*)(✓ Enabled)/g, '$1<span style="color: #00ff00;">$2</span>')
                       .replace(/(VM-x\\/AMD-V\\s*:\\s*)(✗ Disabled)/g, '$1<span style="color: #ff0000;">$2</span>');

            // Network status
            text = text.replace(/(IPv4\\/IPv6\\s*:\\s*)(.+)/g, function(match, prefix, status) {
                let processedStatus = status.replace(/✓ Online/g, '<span style="color: #00ff00;">✓ Online</span>')
                                           .replace(/✗ Offline/g, '<span style="color: #ff0000;">✗ Offline</span>');
                return prefix + processedStatus;
            });

            // I/O Speed
            text = text.replace(/(I\\/O Speed.*:\\s*)(.+)/g, '$1<span style="color: #ffff00;">$2</span>');

            // Organization/Location info
            text = text.replace(/(Organization\\s*:\\s*)(.+)/g, '$1<span style="color: #00ffff;">$2</span>')
                       .replace(/(Location\\s*:\\s*)(.+)/g, '$1<span style="color: #00ffff;">$2</span>')
                       .replace(/(Region\\s*:\\s*)(.+)/g, '$1<span style="color: #ffff00;">$2</span>');

            // Speedtest table processing
            const lines = text.split('\\n');
            let inSpeedTestSection = false;
            let speedTestHeaderFound = false;
            
            for (let i = 0; i < lines.length; i++) {
                const line = lines[i];
                
                if (line.includes('Node Name') && line.includes('Upload Speed') && line.includes('Download Speed') && line.includes('Latency')) {
                    speedTestHeaderFound = true;
                    inSpeedTestSection = true;
                    continue;
                }
                
                if (inSpeedTestSection && speedTestHeaderFound) {
                    if (line.trim() === '' || line.match(/^-+$/)) {
                        inSpeedTestSection = false;
                        continue;
                    }
                    
                    const speedTestMatch = line.match(/^(\\s+)([^\\s].+?)(\\s{2,})([0-9.,]+\\s+[A-Za-z\\/]+)(\\s{2,})([0-9.,]+\\s+[A-Za-z\\/]+)(\\s{2,})([0-9.,]+\\s+[A-Za-z]+)(.*)$/);
                    
                    if (speedTestMatch) {
                        const [, leadingSpace, nodeName, space1, uploadSpeed, space2, downloadSpeed, space3, latency, remaining] = speedTestMatch;
                        
                        lines[i] = leadingSpace + 
                                  '<span style="color: #ffff00;">' + nodeName + '</span>' + space1 +
                                  '<span style="color: #00ff00;">' + uploadSpeed + '</span>' + space2 +
                                  '<span style="color: #ff0000;">' + downloadSpeed + '</span>' + space3 +
                                  '<span style="color: #00ffff;">' + latency + '</span>' + remaining;
                    }
                }
            }
            
            return lines.join('\\n');
        }

        function renderBenchmark(data) {
            const processedData = processAnsiCodes(data);
            
            return \`
                <div class="header">
                    <h1>🚀 VPS Benchmark Results</h1>
                    <p>Generated by Teddysun Bench Script</p>
                    <div style="margin-top: 15px;">
                        <button class="share-btn" onclick="copyToClipboard()">📋 Copy Link</button>
                        <button class="share-btn" onclick="downloadResults()">💾 Download</button>
                    </div>
                </div>
                <div class="benchmark-data">\${processedData}</div>
                <div class="footer">
                    <p>Results permanently saved • <a href="https://benchmark.bibica.net/" target="_blank">Run your own test</a></p>
                </div>
            \`;
        }
        
        function renderWelcome() {
            return \`
                <div class="welcome">
                    <h1>🚀 VPS Benchmark</h1>
                    <p class="subtitle">Comprehensive VPS Performance Testing</p>
                    <div class="command-box">
                        wget -qO- https://go.bibica.net/speedtest | bash
                    </div>
                    <p>Your results will be stored permanently with a clean, shareable URL</p>
                    <div style="margin-top: 30px;">
                        <a href="https://go.bibica.net/speedtest" target="_blank" style="color: #00ffff; text-decoration: none; font-size: 1.1em;">
                            📖 View Script Source
                        </a>
                    </div>
                </div>
            \`;
        }

        function renderError() {
            return \`
                <div style="background: #2a0000; border: 1px solid #ff0000; color: #ff6666; padding: 20px; border-radius: 10px; text-align: center;">
                    <h2>❌ Results Not Found</h2>
                    <p>The benchmark results could not be found or have expired.</p>
                    <p style="margin-top: 15px;">
                        <a href="https://benchmark.bibica.net" style="color: #ff6666;">← Go back to run a new test</a>
                    </p>
                </div>
            \`;
        }

        function copyToClipboard() {
            const urlToCopy = window.location.href.split('#')[0]; // Clean URL without hash
            navigator.clipboard.writeText(urlToCopy).then(() => {
                alert('✅ Link copied to clipboard!');
            }).catch(() => {
                const textArea = document.createElement('textarea');
                textArea.value = urlToCopy;
                document.body.appendChild(textArea);
                textArea.select();
                document.execCommand('copy');
                document.body.removeChild(textArea);
                alert('✅ Link copied to clipboard!');
            });
        }

        function downloadResults() {
            const data = decodeData();
            if (data) {
                let processedData = processAnsiCodes(data);
                processedData = processedData.replace(/<[^>]*>/g, '');
                
                const blob = new Blob([processedData], { type: 'text/plain' });
                const url = URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = \`benchmark-\${new Date().toISOString().split('T')[0]}.txt\`;
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                URL.revokeObjectURL(url);
            }
        }

        // Initialize
        function init() {
            const container = document.getElementById('container');
            const data = decodeData();
            
            if (data === null) {
                container.innerHTML = renderWelcome();
                document.title = 'VPS Benchmark - Performance Testing Tool';
            } else if (data === false) {
                container.innerHTML = renderError();
                document.title = 'Error - VPS Benchmark';
            } else {
                container.innerHTML = renderBenchmark(data);
                document.title = 'Benchmark Results - VPS Performance';
            }
        }

        init();
        window.addEventListener('hashchange', init);
    </script>
</body>
</html>`;
}
