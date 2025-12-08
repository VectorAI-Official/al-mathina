/**
 * Vercel Serverless Function for Sending Emails
 * Unlimited, free email sending via Gmail SMTP
 */

const nodemailer = require('nodemailer');

module.exports = async function handler(req, res) {
  console.log('🔍 Request received');
  console.log('Method:', req.method);
  
  // Security: Check API key
  const apiKey = req.headers['x-api-key'];
  console.log('API Secret check:', { provided: apiKey ? 'yes' : 'no', expected: process.env.API_SECRET ? 'set' : 'missing' });
  
  if (!apiKey || apiKey !== process.env.API_SECRET) {
    console.error('❌ Unauthorized - API key mismatch');
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }

  // Only accept POST requests
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  const { to, subject, html } = req.body;

  // Validate input
  if (!to || !subject || !html) {
    console.error('❌ Missing fields:', { to: !!to, subject: !!subject, html: !!html });
    return res.status(400).json({ 
      success: false, 
      error: 'Missing required fields: to, subject, html' 
    });
  }

  // Check SMTP credentials
  console.log('📋 Checking SMTP credentials...');
  console.log('SMTP_USER set:', process.env.SMTP_USER ? 'yes' : 'NO');
  console.log('SMTP_PASSWORD set:', process.env.SMTP_PASSWORD ? 'yes' : 'NO');

  if (!process.env.SMTP_USER || !process.env.SMTP_PASSWORD) {
    console.error('❌ SMTP credentials missing!');
    return res.status(500).json({ 
      success: false, 
      error: 'SMTP credentials not configured'
    });
  }

  // Create SMTP transporter with Gmail
  console.log('🔧 Creating transporter...');
  const transporter = nodemailer.createTransporter({
    service: 'gmail',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASSWORD,
    },
  });

  try {
    console.log(`📧 Sending email to: ${Array.isArray(to) ? to.join(', ') : to}`);
    console.log(`📧 Subject: ${subject}`);
    
    // Send email
    const info = await transporter.sendMail({
      from: process.env.SMTP_USER,
      to: Array.isArray(to) ? to.join(',') : to,
      subject,
      html,
    });

    console.log(`✅ Email sent successfully! Message ID: ${info.messageId}`);
    
    return res.status(200).json({ 
      success: true, 
      messageId: info.messageId,
      accepted: info.accepted,
      rejected: info.rejected
    });
    
  } catch (error) {
    console.error('❌ Email error:', error.message);
    console.error('Error stack:', error.stack);
    return res.status(500).json({ 
      success: false, 
      error: error.message,
      type: error.name
    });
  }
};
