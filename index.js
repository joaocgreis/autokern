process.setSourceMapsEnabled(true)
if (process.env.NODE_OPTIONS) {
  process.env.NODE_OPTIONS += ' --enable-source-maps'
} else {
  process.env.NODE_OPTIONS = '--enable-source-maps'
}
require('coffeescript/register')
require('./index.coffee')
