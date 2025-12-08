/**
 * Vercel Serverless Function for Sending Emails
 * Unlimited, free email sending via Gmail SMTP
 */

const nodemailer = require('nodemailer');

export default async function handler(req, res) {
  // Security: Check API key
  const apiKey = req.headers['x-api-key'];
  if (!apiKey || apiKey !== process.env.API_SECRET) {
    console.error('Unauthorized request - invalid API key');
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }

  // Only accept POST requests
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  const { to, subject, html } = req.body;

  // Validate input
  if (!to || !subject || !html) {
    return res.status(400).json({ 
      success: false, 
      error: 'Missing required fields: to, subject, html' 
    });
  }

  // Create SMTP transporter with Gmail
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
    console.error('❌ Email error:', error);
    return res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
}
