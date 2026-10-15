(function(dictionary) {
  function text(value, keys) {
    if (Array.isArray(value)) return value.map(v => text(v, keys));
    if (typeof value !== 'string') return value;
    if (keys.includes(value) && dictionary[value]) return dictionary[value];
    for (const key of keys) {
      if ((key.trim().length < 4 && !/^\s|\s$/.test(key)) || !dictionary[key]) continue;
      if (value.startsWith(key)) return dictionary[key] + value.slice(key.length);
      if (value.endsWith(key)) return value.slice(0,-key.length) + dictionary[key];
    }
    return value;
  }
  function title(original) {
    const react = window.SP_REACT;
    if (!react || typeof react.createElement !== 'function') return original;
    return react.createElement('div', null, original,
      react.createElement('div', {style: {color: '#ffcc66', fontSize: '13px', fontWeight: 700}}, 'RenAmamiya汉化'));
  }
  return {text, title};
})
