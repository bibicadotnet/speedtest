// functions/[slug].js
export async function onRequestGet(context) {
    const { params, env, request } = context;
    const slug = params.slug;
    
    // Validate slug format (8 hex chars)
    if (!/^[a-f0-9]{8}$/i.test(slug)) {
        // Redirect to homepage thay vì return HTML
        return Response.redirect('https://benchmark.bibica.net/', 302);
    }
    
    try {
        // Lấy data từ D1
        const stmt = env.DB.prepare('SELECT data FROM benchmarks WHERE slug = ?');
        const result = await stmt.bind(slug).first();
        
        if (!result) {
            // Redirect to homepage nếu không tìm thấy
            return Response.redirect('https://benchmark.bibica.net/', 302);
        }
        
        // Update access count (fire-and-forget)
        const updateStmt = env.DB.prepare(`
            UPDATE benchmarks 
            SET accessed_count = accessed_count + 1, last_accessed = ? 
            WHERE slug = ?
        `);
        updateStmt.bind(new Date().toISOString(), slug).run().catch(console.error);
        
        // Fetch index.html từ static files
        const indexResponse = await env.ASSETS.fetch(new Request('https://benchmark.bibica.net/index.html'));
        let indexHTML = await indexResponse.text();
        
        // Inject data vào HTML
        indexHTML = indexHTML.replace(
            'const serverData = null;', 
            `const serverData = ${JSON.stringify(result.data)};`
        );
        
        // Update meta tags cho SEO
        indexHTML = indexHTML.replace(
            '<title>VPS Benchmark - Performance Testing</title>',
            '<title>Benchmark Results - VPS Performance Testing</title>'
        );
        
        indexHTML = indexHTML.replace(
            '<meta name="description" content="VPS server performance benchmark results including CPU, memory, disk I/O and network speed tests.">',
            '<meta name="description" content="Detailed VPS benchmark results with CPU, memory, disk I/O and network performance metrics.">'
        );
        
        // Update Open Graph tags
        indexHTML = indexHTML.replace(
            '<meta property="og:title" content="VPS Benchmark Tool">',
            '<meta property="og:title" content="VPS Benchmark Results">'
        );
        
        indexHTML = indexHTML.replace(
            `<meta property="og:url" content="https://benchmark.bibica.net">`,
            `<meta property="og:url" content="https://benchmark.bibica.net/${slug}">`
        );
        
        return new Response(indexHTML, {
            headers: { 
                'Content-Type': 'text/html',
                'Cache-Control': 'public, max-age=3600'
            }
        });
        
    } catch (error) {
        console.error('Database error:', error);
        return Response.redirect('https://benchmark.bibica.net/', 302);
    }
}
