'use strict';

const prefix = {
  info: '[funclash]',
  warn: '[funclash][warn]',
  error: '[funclash][error]',
};

module.exports = {
  info: (...args) => console.log(prefix.info, ...args),
  warn: (...args) => console.warn(prefix.warn, ...args),
  error: (...args) => console.error(prefix.error, ...args),
};
