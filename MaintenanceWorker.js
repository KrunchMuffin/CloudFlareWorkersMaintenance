const WHITE_LIST = [
  'nnn.nnn.nnn.nnn'
];

// Paths that require IP whitelist checking
const PROTECTED_PATHS = [
  '/admin/',
  '/pages/'
];

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const clientIP = request.headers.get("cf-connecting-ip") || request.cf?.ip;
    
    // Check if the requested path starts with any of the protected paths
    const isProtectedPath = PROTECTED_PATHS.some(path => 
      url.pathname.toLowerCase().startsWith(path.toLowerCase())
    );
    
    // If it's not a protected path, allow access without IP check
    if (!isProtectedPath) {
      return fetch(request);
    }
    
    // For protected paths, check IP whitelist
    if (WHITE_LIST.includes(clientIP)) {
      return fetch(request);
    }

    const modifiedHeaders = new Headers({
      'Content-Type': 'text/html;charset=UTF-8',
      'Cache-Control': 'no-store, no-cache, must-revalidate',
      'Pragma': 'no-cache'
    });

    return new Response(maintPage, {
      status: 503,
      headers: modifiedHeaders
    });
  }
};

const maintPage = `/* Your HTML content */`;
