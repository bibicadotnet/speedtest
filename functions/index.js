export async function onRequest(context) {
  const { request } = context;
  const url = new URL(request.url);
  const pathname = url.pathname;
  
  // Nếu là root path
  if (pathname === '/') {
    const userAgent = request.headers.get('User-Agent') || '';
    
    // Kiểm tra nếu là command line tools
    if (userAgent.match(/wget|curl|bash|sh/i)) {
      return Response.redirect('https://raw.githubusercontent.com/bibicadotnet/speedtest/main/bench.sh', 302);
    }
  }
  
  // Nếu không, tiếp tục serve static files
  return context.next();
}
