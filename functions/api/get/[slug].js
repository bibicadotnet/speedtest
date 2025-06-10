export async function onRequestGet(context) {
  const slug = context.params.slug;
  if (!slug) return new Response("Invalid", { status: 400 });

  const result = await context.env.DB.prepare(
    "SELECT data FROM benchmarks WHERE slug = ?"
  ).bind(slug).first();

  if (!result) {
    return new Response("Not found", { status: 404 });
  }

  return new Response(JSON.stringify({ data: result.data }), {
    headers: { "Content-Type": "application/json" }
  });
}
