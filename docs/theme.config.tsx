import React from 'react'
import { useRouter } from "next/router"
import { DocsThemeConfig } from 'nextra-theme-docs'

const config: DocsThemeConfig = {
  useNextSeoProps() {
		const { asPath } = useRouter()
		if (asPath !== "/") {
			return {
				titleTemplate: "%s – Blink",
			}
		}
	},
  logo: <span>Blink</span>,
  project: {
    link: 'https://github.com/1Axen/blink',
  },
  docsRepositoryBase: 'https://github.com/1Axen/blink',
  footer: {
    text: '© 2024 Blink',
  },
}

export default config
