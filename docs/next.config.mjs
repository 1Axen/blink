import nextra from 'nextra'
import { BUNDLED_LANGUAGES, getHighlighter } from 'shiki'

const withNextra = nextra({
  theme: 'nextra-theme-docs',
  themeConfig: './theme.config.tsx',
  mdxOptions: {
     rehypePrettyCodeOptions: {
      getHighlighter: options =>
        getHighlighter({
          ...options,
          langs: [
            ...BUNDLED_LANGUAGES,
            {
              id: 'blink',
              scopeName: 'source.blink',
              aliases: [],
              path: '../../public/blink.tmLanguage.json'
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
