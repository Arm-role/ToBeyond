// Generate .import files for all new SVGs using the same template as ball.svg.import
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const template = (relPath, md5) => `[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://PLACEHOLDER_${md5.slice(0, 12)}"
path="res://.godot/imported/${path.basename(relPath)}-${md5}.ctex"
metadata={
"vram_texture": false
}

[deps]

source_file="res://${relPath.replace(/\\/g, '/')}"
dest_files=["res://.godot/imported/${path.basename(relPath)}-${md5}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
svg/scale=1.0
editor/scale_with_editor_scale=false
editor/convert_colors_with_editor_theme=false
`;

function walk(dir) {
  const results = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) results.push(...walk(fullPath));
    else if (entry.name.endsWith('.svg')) results.push(fullPath);
  }
  return results;
}

const svgFiles = walk('assets');
let created = 0;

for (const svgPath of svgFiles) {
  const importPath = svgPath + '.import';
  if (fs.existsSync(importPath)) continue;

  const content = fs.readFileSync(svgPath);
  const md5 = crypto.createHash('md5').update(content).digest('hex');
  const relPath = svgPath.replace(/\\/g, '/');
  
  fs.writeFileSync(importPath, template(relPath, md5), 'utf-8');
  created++;
  console.log('Created:', importPath);
}

console.log('\nTotal .import files created:', created);
