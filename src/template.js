#!/bin/env node
const fs = require('fs');

const reTemplate = /^!\s*domain_shortcut\((.*)\)\s*$/,
    reDomain = /^((?:(?:[A-Za-z0-9]-*)*[A-Za-z0-9]+)(?:\.(?:[A-Za-z0-9]-*)*[A-Za-z0-9]+)*(?:\.(?:[A-Za-z]{2,})))\s*$/,
    reReference = /^\{(.*)\}\s*$/,
    reInstruction = /#@?[%\$]?#/,
    reDomainModifier = /\$(?:.*\,)?domain=(?:.*\|)?$/,
    reWhitespace = /^\s*$/,
    reComment = /^!/;

const map = Object.create(null);

let line, file, i = 0, l;

const makeError = () => {
    console.error('Invalid line ' + line + ' in file ' + file + ' at line ' + (i + 1));
    process.exit(1);
};

file = 'domain_shortcuts.txt';
let templates = fs.readFileSync(file, 'utf8').toString().split(/\r?\n/);

let shortcut;

for(l = templates.length; i < l; i++) {
    line = templates[i];
    let match;
    if(reWhitespace.test(line)) continue;
    else if(match = reTemplate.exec(line)) shortcut = match[1];
    else if(match = reDomain.exec(line)) {
        let domain = match[1], prev = map[shortcut];
        if(prev) prev.push(domain);
        else map[shortcut] = [domain];
    }
    else if(match = reReference.exec(line)) {
        let another = map[match[1]], prev = map[shortcut];
        if(typeof another == 'undefined') makeError();
        if(prev) map[shortcut] = prev.concat(another);
        else map[shortcut] = another;
    }
    else makeError();
}

for(file of ['filter.txt', 'unbreak.txt']) {
    let rules = fs.readFileSync(file, 'utf8').toString().split(/\r?\n/);

    for(i = 0, l = rules.length; i < l; i++) {
        line = rules[i];
        if(reWhitespace.test(line) || reComment.test(line)) continue;
        for(shortcut in map) {
            line = line.replace(new RegExp('\\{' + shortcut + '\\}'), () => {
                let l = RegExp.leftContext, r = RegExp.rightContext, splitter;
                if(reInstruction.test(r)) splitter = ',';
                else if(reDomainModifier.test(l)) splitter = '|';
                else if(l == '@@||') splitter = r + '\n@@||';
                else makeError();
                return map[shortcut].join(splitter);
            });
        }
        rules[i] = line;
    }

    fs.writeFileSync('../' + file, rules.join('\n'), 'utf8');
}
