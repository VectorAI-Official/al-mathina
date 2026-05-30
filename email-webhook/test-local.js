const http = require('http');
const handler = require('./api/send-email.js');

// Set environment variables
process.env.API_SECRET = 'rVQaCTKzoesZ5DcNjMhx4F1uL7gynSJk';
process.env.SMTP_USER = 'almathina64@gmail.com';
process.env.SMTP_PASSWORD = 'cgpj fbdz srve oqhn';

const server = http.createServer(async (req, res) => {
  // Only handle /api/send-email
  if (req.url !== '/api/send-email') {
    res.writeHead(404);
    res.end('Not found');
    return;
  }

  // Parse JSON body
  if (req.method === 'POST') {
    let body = '';
    req.on('data', chunk => {
      body += chunk.toString();
    });
    req.on('end', async () => {
      try {
        req.body = JSON.parse(body);
        await handler(req, res);
      } catch (err) {
        console.error('Error:', err);
        res.writeHead(500);
        res.end(JSON.stringify({ error: err.message }));
      }
    });
  } else {
    res.writeHead(405);
    res.end('Method not allowed');
  }
});

const PORT = 3000;
server.listen(PORT, () => {
  console.log(`✅ Local email server running on http://localhost:${PORT}`);
  console.log(`📧 API Secret: rVQaCTKzoesZ5DcNjMhx4F1uL7gynSJk`);
  console.log(`📧 SMTP User: almathina64@gmail.com`);
});
