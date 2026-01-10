return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = true,
        always_show = {
          -- hide_gitignored が true でも、これらは常に表示したい場合に指定
          ".env",
          ".gitignore",
        },
      },
    },
  },
}
