import { readFileSync } from 'fs'
import nextra from 'nextra'
import { BUNDLED_LANGUAGES, getHighlighter } from 'shiki'

const withNextra = nextra({
  theme: 'nextra-theme-docs',
  themeConfig: './theme.config.tsx',
  mdxOptions: {
     rehypePrettyCodeOptions: {
      theme: JSON.parse(
        readFileSync('./public/syntax/mocha.json', 'utf8')
      ),
      getHighlighter: options =>
        getHighlighter({
          ...options,
          langs: [
            ...BUNDLED_LANGUAGES,
            {
              id: 'blink',
              scopeName: 'source.blink',
              aliases: [],
              path: '../../public/syntax/blink.tmLanguage.json'
            }
          ]
        })
    }
  }
})

export default withNextra({
  output: "export",
  basePath: "/blink",
  images: {unoptimized: true}
})
