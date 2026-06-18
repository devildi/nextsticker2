const fs = require('fs');

try {
  const xml = fs.readFileSync('shared_prefs.xml', 'utf8');
  
  // Find the flutter.local_stories string tag
  const match = xml.match(/<string name="flutter\.local_stories">([\s\S]*?)<\/string>/);
  if (!match) {
    console.log('No local_stories found in preferences.');
    process.exit(0);
  }
  
  // Decode XML entities
  let jsonStr = match[1]
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&#10;/g, '\n')
    .replace(/&#13;/g, '\r');
    
  const stories = JSON.parse(jsonStr);
  console.log(`Loaded ${stories.length} stories from local cache:`);
  
  // Find the flutter.auth string tag
  const authMatch = xml.match(/<string name="flutter\.auth">([\s\S]*?)<\/string>/);
  if (authMatch) {
    let authJsonStr = authMatch[1]
      .replace(/&quot;/g, '"')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&#10;/g, '\n')
      .replace(/&#13;/g, '\r');
    console.log('Logged-in Auth:', JSON.stringify(JSON.parse(authJsonStr), null, 2));
  } else {
    console.log('No logged-in auth found.');
  }
} catch (e) {
  console.error('Failed to parse prefs:', e);
}
