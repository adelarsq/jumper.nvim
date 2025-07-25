
(when vim.g.loaded_jumper (lua "return "))

(local M {})

;; Initiate file list
(local files (or vim.g.file_list {}))

;; Get path for oil plugin
(fn get-oil-file-path []
  (let [(use imported) (pcall require :oil)]
    (when use
      (local entry (imported.get_cursor_entry))
      (when (= (. entry :type) :file)
        (local dir (imported.get_current_dir))
        (local file-name (. entry :name))
        (local full-name (.. dir file-name))
        (let [return1 full-name]
          (lua "return return1"))))
    ""))

;; Get path for nvim-tree plugin
(fn get-nvim-tree-file-path []
  (let [(use imported) (pcall require :nvim-tree.lib)]
    (when use (local entry (imported.get_node_at_cursor))
      (let [return1 entry.absolute_path]
        (lua "return return1")))
    ""))

;; Add files on the list
(fn add-current-file []
  (var current-file "")
  (local filetype vim.bo.filetype)

  (if (= filetype :oil)
        (set current-file (get-oil-file-path {}))
      (= filetype :NvimTree)
        (set current-file (get-nvim-tree-file-path {}))
      (set current-file (vim.fn.expand "%:p")))

  (when (not (vim.tbl_contains files current-file))
    (table.insert files current-file)
    (vim.api.nvim_echo [[(.. "Added " current-file " to the list.")]] false {})
    (set vim.g.file_list files)))

;; Get current file list
(fn get-file-list []
  ; (vim.api.nvim_echo [["Current file list:" "None"]] false {})
  (local list {})
  (each [i file (ipairs files)]
    (local dic {:filename file :text ""})
    (table.insert list dic))
  (vim.fn.setqflist list)
  (vim.cmd "bel copen 10"))

;; Navigate to a file by index
(fn navigate-to-file [index]
  (local file (vim.fn.get files index))
  (if file
      (vim.cmd (.. "edit " file))
      ; (vim.api.nvim_echo [[(.. "Invalid index: " index) "ErrorMsg"]] false {})
  )
)

(fn navigate-to-next-file []
   (let [current-index (vim.fn.index files (vim.fn.expand "%:p"))]
     (let [next-index (if (= (+ current-index 1) (length files))
                          0
                          (+ current-index 1))]
        (navigate-to-file next-index)
     )
   )
)

;; Allows to create one terminal per tab
(set vim.t.terminal_bufnr nil)

;; Command that toggle the terminal or open a new
(fn toggle-or-open-terminal []
  (if (and vim.t.terminal_bufnr (vim.api.nvim_buf_is_valid vim.t.terminal_bufnr))
      (if (= (vim.api.nvim_get_current_buf) vim.t.terminal_bufnr)
          (vim.api.nvim_command "b#")
          (vim.api.nvim_command (.. "buffer " vim.t.terminal_bufnr))
          (vim.api.nvim_feedkeys "i" "n" false))
      (do
        (vim.api.nvim_command "enew")  ; allows to go back
        (vim.api.nvim_command "terminal")
        (set vim.t.terminal_bufnr (vim.api.nvim_get_current_buf))
        (vim.api.nvim_feedkeys "i" "n" false))))

;; Command that add current file
(vim.api.nvim_create_user_command "JumperAdd" add-current-file {})

;; Command that show current file list
(vim.api.nvim_create_user_command "JumperList" get-file-list {})

;; Command to navigage to the given file index
(vim.api.nvim_create_user_command "JumperJump" (fn [opts]
  (navigate-to-file (tonumber (vim.fn.input "Enter file index: "))))
  {})

;; Command to navigate to the next file
(vim.api.nvim_create_user_command "JumperNext" navigate-to-next-file {})

(vim.api.nvim_create_user_command "JumperTerminal" toggle-or-open-terminal {})

(fn M.setup []
  (set vim.g.loaded_jumper 1))

M


