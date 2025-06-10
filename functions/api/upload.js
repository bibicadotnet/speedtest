// functions/api/upload.js
export async function onRequestPost(context) {
    const { request, env } = context;
    
    try {
        const { data } = await request.json();
        
        // Validate input
        if (!data || typeof data !== 'string') {
            return new Response(JSON.stringify({ 
                success: false, 
                error: 'Invalid data format' 
            }), {
                status: 400,
                headers: { 
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                }
            });
        }
        
        // Validate base64 và size
        if (data.length > 50000) { // ~37KB after base64 decode
            return new Response(JSON.stringify({ 
                success: false, 
                error: 'Data too large' 
            }), {
                status: 413,
                headers: { 
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                }
            });
        }
        
        // Test decode để ensure valid base64
        try {
            atob(data);
        } catch (e) {
            return new Response(JSON.stringify({ 
                success: false, 
                error: 'Invalid base64 data' 
            }), {
                status: 400,
                headers: { 
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                }
            });
        }
        
        // Generate slug từ hash của data
        const encoder = new TextEncoder();
        const hashBuffer = await crypto.subtle.digest('SHA-256', encoder.encode(data));
        const hashArray = Array.from(new Uint8Array(hashBuffer));
        const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
        const slug = hashHex.substring(0, 8); // 8 chars
        
        // Lưu vào D1 (INSERT OR REPLACE để handle duplicates)
        const stmt = env.DB.prepare(`
            INSERT OR REPLACE INTO benchmarks (slug, data, created_at, accessed_count, last_accessed) 
            VALUES (?, ?, ?, COALESCE((SELECT accessed_count FROM benchmarks WHERE slug = ?), 0), ?)
        `);
        
        const now = new Date().toISOString();
        await stmt.bind(slug, data, now, slug, now).run();
        
        const url = `https://benchmark.bibica.net/${slug}`;
        
        return new Response(JSON.stringify({ 
            success: true,
            slug: slug,
            url: url
        }), {
            headers: { 
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            }
        });
        
    } catch (error) {
        console.error('Upload error:', error);
        return new Response(JSON.stringify({ 
            success: false, 
            error: 'Internal server error' 
        }), {
            status: 500,
            headers: { 
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            }
        });
    }
}

// Handle CORS preflight
export async function onRequestOptions() {
    return new Response(null, {
        headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
        }
    });
}
