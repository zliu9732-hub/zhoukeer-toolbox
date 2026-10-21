(function(dictionary, patterns = []) {
  const messagePatterns=patterns.map(parts=>({parts,regex:new RegExp('^'+parts.map(part=>part===null?'([\\s\\S]*?)':part.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')).join('')+'$')}));
  function text(value, keys) {
    if (Array.isArray(value)) return value.map(v => text(v, keys));
    if (typeof value !== 'string') return value;
    if (keys.includes(value) && dictionary[value]) return dictionary[value];
    // A template can have both a translated prefix and suffix. Apply both while
    // leaving inserted game names, versions and other dynamic values untouched.
    let result = value;
    const applied = new Set();
    for (const key of [...keys].sort((a,b) => b.length-a.length)) {
      if ((key.trim().length < 4 && !/^\s|\s$/.test(key)) || !dictionary[key]) continue;
      if (result.startsWith(key)) {result = dictionary[key] + result.slice(key.length); applied.add(key);}
      if (result.endsWith(key)) {result = result.slice(0,-key.length) + dictionary[key]; applied.add(key);}
    }
    // These keys come only from literals traced in this UI expression, such as
    // the source-name alternatives inside `No ${sourceName} found`. Dynamic
    // game names and identifiers do not contribute dictionary keys.
    for (const key of [...keys].sort((a,b) => b.length-a.length)) {
      if (!applied.has(key) && key.trim().length >= 4 && dictionary[key]) result = result.split(key).join(dictionary[key]);
    }
    return result;
  }
  function title(original) {
    const react = window.SP_REACT;
    if (!react || typeof react.createElement !== 'function') return original;
    return react.createElement('div', null, original,
      react.createElement('div', {style: {color: '#ffcc66', fontSize: '13px', fontWeight: 700}}, 'RenAmamiya汉化'));
  }
  function registration(original, translated) {
    if (original !== 'Decky LSFG-VK' && original !== '小黄鸭2.0') throw new Error('Unsupported plugin registration');
    if (translated !== '小黄鸭2.0') throw new Error('Unsupported translated registration');
    return translated;
  }
  function resource(original, oldName, translated) {
    const prefix = 'http://127.0.0.1:1337/plugins/' + oldName + '/';
    if (!original.startsWith(prefix)) throw new Error('Unsupported plugin resource');
    return 'http://127.0.0.1:1337/plugins/' + encodeURIComponent(translated) + '/' + original.slice(prefix.length);
  }
  function message(value) {
    if (typeof value !== 'string') return value;
    if (Object.prototype.hasOwnProperty.call(dictionary, value)) return dictionary[value];
    if (value.startsWith('Error: ') && dictionary['Error: ']) return dictionary['Error: ']+message(value.slice(7));
    for (const pattern of messagePatterns) {
      const match=pattern.regex.exec(value);
      if (!match) continue;
      let capture=0;
      return pattern.parts.map(part=>part===null?match[++capture]:(dictionary[part]??part)).join('');
    }
    // Only explicit diagnostic prefixes; preserve the dynamic error/path after
    // the prefix and never scan arbitrary game names or config file contents.
    const prefix=Object.keys(dictionary).filter(key=>key.length>=8 && key.endsWith(': '))
      .sort((a,b)=>b.length-a.length).find(key=>value.startsWith(key));
    return prefix ? dictionary[prefix]+value.slice(prefix.length) : value;
  }
  function toast(value) {
    return {...value, title: message(value.title), body: message(value.body)};
  }
  return {text, title, registration, resource, message, toast};
})
