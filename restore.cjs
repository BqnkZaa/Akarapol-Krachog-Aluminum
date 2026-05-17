const fs = require('fs');
const log = fs.readFileSync('C:\\Users\\ayumg\\.gemini\\antigravity\\brain\\f14864a3-7153-466f-b928-927de569af6b\\.system_generated\\logs\\overview.txt', 'utf8');
const lines = log.split('\n');
const files = [
  'src/app/admin/categories/page.tsx',
  'src/components/CategoryForm.tsx',
  'src/app/admin/templates/page.tsx',
  'src/components/TemplateForm.tsx',
  'src/components/TemplateFormSections.tsx',
  'src/components/CategoryActions.tsx',
  'src/components/TemplateActions.tsx'
];
files.forEach(f => {
  const fWin = 'd:\\\\Workshop\\\\aluminum\\\\' + f.replace(/\//g, '\\\\');
  for(let i=lines.length-1; i>=0; i--){
    if(lines[i].includes('write_to_file') && lines[i].includes(fWin)){
      const match = lines[i].match(/\"CodeContent\":\"\\\\\"([\\s\\S]*?)\\\\\"\"/);
      if(match){
         let content = match[1].replace(/\\\\n/g, '\n').replace(/\\\\\"/g, '\"');
         content = content.replace(/\\\\\\\\/g, '\\\\');
         fs.writeFileSync(f, content, 'utf8');
         console.log('Restored', f);
         break;
      }
    }
  }
});
