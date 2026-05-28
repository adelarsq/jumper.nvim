
(when vim.g.loaded_jumper (lua "return "))

(local M {})

;; Initiate file list
(local files (or vim.g.file_list []))

;; Get path for oil plugin
(fn get-oil-file-path []
  (let [(use imported) (pcall require :oil)]
    (when use
      (local entry (imported.get_cursor_entry))
      (when (= (. entry :type) :file)
        (local dir (imported.get_current_dir))
        (local file-name (. entry :name))
        (.. dir file-name)))
    ""))

;; Get path for nvim-tree plugin
(fn get-nvim-tree-file-path []
  (let [(use imported) (pcall require :nvim-tree.lib)]
    (when use
      (local entry (imported.get_node_at_cursor))
      entry.absolute_path)
    ""))

;; Add files on the list
(fn add-current-file []
  (var current-file "")
  (local filetype vim.bo.filetype)

  (if (= filetype :oil)
        (set current-file (get-oil-file-path))
      (= filetype :NvimTree)
        (set current-file (get-nvim-tree-file-path))
      (set current-file (vim.fn.expand "%:p")))

  (when (and current-file (not= current-file "")
             (not (vim.tbl_contains files current-file)))
    (table.insert files current-file)
    (vim.api.nvim_echo [[(.. "Added " current-file " to the list.")]] false {})
    (set vim.g.file_list files)))

;; Get current file list with vim.ui.select support
(fn get-file-list []
  (if (= (length files) 0)
      (vim.api.nvim_echo [["No files in the list." "WarningMsg"]] false {})
      (let [items []]
        (each [i file (ipairs files)]
          (table.insert items {:index i :filename file :text file}))
        
        (vim.ui.select items
          {:prompt "Select file to open:"
           :format_item (fn [item]
                          (.. item.index ": " (vim.fn.fnamemodify item.filename ":~")))
           :kind "file"}
          (fn [choice]
            (when choice
              (vim.cmd (.. "edit " choice.filename))))))))

;; Legacy function to show in quickfix (backward compatibility)
(fn get-file-list-quickfix []
  (local list [])
  (each [i file (ipairs files)]
    (local dic {:filename file :text (.. i ": " (vim.fn.fnamemodify file ":~"))})
    (table.insert list dic))
  (vim.fn.setqflist list)
  (vim.cmd "bel copen 10"))

;; Clear file list
(fn clear-file-list []
  (set vim.g.file_list {})
  (vim.api.nvim_echo [["File list cleared." "WarningMsg"]] false {}))

;; Navigate to a file by index (1-based)
(fn navigate-to-file [index]
  (let [len (length files)]
    (if (and index (>= index 1) (<= index len))
        (let [file (. files index)]
          (vim.cmd (.. "edit " file)))
        (vim.api.nvim_echo [[(.. "Invalid index: " (or index "nil") ". Valid range: 1-" len) "ErrorMsg"]] false {}))))

;; Navigate to a file using vim.ui.select
(fn navigate-to-file-select []
  (if (= (length files) 0)
      (vim.api.nvim_echo [["No files in the list." "WarningMsg"]] false {})
      (let [items []]
        (each [i file (ipairs files)]
          (table.insert items {:index i :filename file :text file}))
        
        (vim.ui.select items
          {:prompt "Jump to file:"
           :format_item (fn [item]
                          (.. item.index ": " (vim.fn.fnamemodify item.filename ":~")))
           :kind "file"}
          (fn [choice]
            (when choice
              (vim.cmd (.. "edit " choice.filename))))))))

;; Find current file index in the list
(fn get-current-file-index []
  (let [current-file (vim.fn.expand "%:p")
        len (length files)]
    (var found-index -1)
    (for [i 1 len]
      (when (= (. files i) current-file)
        (set found-index i)))
    found-index))

;; Navigate to next file (with wrap-around)
(fn navigate-to-next-file []
  (let [len (length files)]
    (if (= len 0)
        (vim.api.nvim_echo [["No files in the list." "WarningMsg"]] false {})
        (let [current-index (get-current-file-index)]
          (if (>= current-index 1)
              ;; Current file is in the list, go to next with wrap-around
              (let [next-index (if (= current-index len) 1 (+ current-index 1))]
                (navigate-to-file next-index))
              ;; Current file not in list, start from first
              (navigate-to-file 1))))))

;; Navigate to previous file (with wrap-around)
(fn navigate-to-previous-file []
  (let [len (length files)]
    (if (= len 0)
        (vim.api.nvim_echo [["No files in the list." "WarningMsg"]] false {})
        (let [current-index (get-current-file-index)]
          (if (>= current-index 1)
              ;; Current file is in the list, go to previous with wrap-around
              (let [prev-index (if (= current-index 1) len (- current-index 1))]
                (navigate-to-file prev-index))
              ;; Current file not in list, start from last
              (navigate-to-file len))))))

;; Allows to create one terminal per tab
(set vim.t.terminal_bufnr nil)

;; Command that toggle the terminal or open a new
(fn toggle-or-open-terminal []
  (if (and vim.t.terminal_bufnr (vim.api.nvim_buf_is_valid vim.t.terminal_bufnr))
      (if (= (vim.api.nvim_get_current_buf) vim.t.terminal_bufnr)
          (vim.api.nvim_command "b#")
          (do
            (vim.api.nvim_command (.. "buffer " vim.t.terminal_bufnr))
            (vim.api.nvim_feedkeys "i" "n" false)))
      (do
        (vim.api.nvim_command "enew")  ; allows to go back
        (vim.api.nvim_command "terminal")
        (set vim.t.terminal_bufnr (vim.api.nvim_get_current_buf))
        (vim.api.nvim_feedkeys "i" "n" false))))

;; Command that add current file
(vim.api.nvim_create_user_command "JumperAdd" add-current-file {})

;; Command that show current file list with vim.ui.select
(vim.api.nvim_create_user_command "JumperList" get-file-list {})

;; Command that show in quickfix (alternative)
(vim.api.nvim_create_user_command "JumperListQF" get-file-list-quickfix {})

;; Command that clear current file list
(vim.api.nvim_create_user_command "JumperClear" clear-file-list {})

;; Command to navigate to the given file index or show menu
(vim.api.nvim_create_user_command "JumperJump" (fn [opts]
  (if (= (length files) 0)
      (vim.api.nvim_echo [["No files in the list." "WarningMsg"]] false {})
      ;; If count is provided, jump directly
      (if (and opts.count (> opts.count 0))
          (navigate-to-file opts.count)
          ;; Otherwise show vim.ui.select menu
          (navigate-to-file-select))))
  {:count true})

;; Command to navigate to the next file
(vim.api.nvim_create_user_command "JumperNext" navigate-to-next-file {})

;; Command to navigate to the previous file
(vim.api.nvim_create_user_command "JumperPrevious" navigate-to-previous-file {})

;; Terminal command
(vim.api.nvim_create_user_command "JumperTerminal" toggle-or-open-terminal {})

(fn M.setup []
  (set vim.g.loaded_jumper 1))

M

