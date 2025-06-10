export async function onRequestPost(context) {
    const body = await context.request.json();
    const { slug, data } = body;

    await context.env.DB.prepare(
        "INSERT OR REPLACE INTO benchmarks (slug, data) VALUES (?, ?)"
    ).bind(slug, data).run();

    return new Response(JSON.stringify({ ok: true, slug }), {
        headers: { "Content-Type": "application/json" }
    });
}
