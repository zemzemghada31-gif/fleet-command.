const fs = require('fs');

const files = [
  'C:/Users/FARAH/Desktop/manus/frontend/lib/pages/trajectory_page.dart',
  'C:/Users/FARAH/Desktop/manus/frontend/lib/pages/devices_page.dart',
  'C:/Users/FARAH/Desktop/manus/frontend/lib/pages/analytics_page.dart',
  'C:/Users/FARAH/Desktop/manus/frontend/lib/pages/dashboard_page.dart',
];

files.forEach(f => {
  let c = fs.readFileSync(f, 'utf8');
  c = c.replace(/\.withOpacity\(([^)]+)\)/g, '.withValues(alpha: $1)');
  c = c.replace(/\bprint\(/g, 'debugPrint(');
  fs.writeFileSync(f, c, 'utf8');
  console.log('fixed: ' + f.split('/').pop());
});
