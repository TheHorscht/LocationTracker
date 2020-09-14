const fs = require('fs');
const AdmZip = require('adm-zip');
const path = require('path');
const minimatch = require("minimatch");
const pjson = require('./package.json');
const parseString = require('util').promisify(require('xml2js').parseString);

const scriptName = path.basename(__filename);

let preview = false;

const args = process.argv.slice(2);
args.forEach(val => {
  if(val == '--preview') {
    preview = true;
  }
});

// Config
const out_dir = __dirname + '/dist';
const name = 'LocationTracker';
const version = pjson.version;
const root_folder = __dirname;
const ignore_list = [
  '.git',
  '.gitignore',
  'workshop.xml',
  'workshop_id.txt',
  'workshop_preview_image.png',
  'mod_id.txt',
  'compatibility.xml'
];
// Config end

ignore_list.push(scriptName);

function is_dir(path) {
  try {
      var stat = fs.lstatSync(path);
      return stat.isDirectory();
  } catch (e) {
      // lstatSync throws an error if path doesn't exist
      return false;
  }
}

const zip = new AdmZip();

const addFiles = item => {
  if(ignore_list.every(ignore_entry => !minimatch(item, ignore_entry))) {
    if(is_dir(__dirname + '/' + item)) {
      fs.readdirSync(__dirname + '/' + item).forEach(entry => {
        const child_item = `${item}/${entry}`;
        addFiles(child_item);
      });
    } else {
      const folderName = item.substr(0, item.lastIndexOf('/'));
      if(preview) {
        console.log(item);
      } else {
        zip.addLocalFile(`${__dirname}/${item}`, `${name}/${folderName}`);
      }
    }
  }
};

(async function() {
  let xml = fs.readFileSync(__dirname + '/workshop.xml', 'utf8');
  let parsedXML = await parseString(xml);
  let dont_upload_folders = parsedXML.Mod.$.dont_upload_folders.split("|");
  let dont_upload_files = parsedXML.Mod.$.dont_upload_files.split("|");
  ignore_list.push(...dont_upload_folders);
  ignore_list.push(...dont_upload_files);
  
  fs.readdirSync(root_folder).forEach(entry => {
    addFiles(entry);
  });
  
  if(!preview) {
    if (!fs.existsSync(out_dir)) {
      fs.mkdirSync(out_dir);
    }
    zip.writeZip(`${out_dir}/${name}_v${version}.zip`);
  }
})()
