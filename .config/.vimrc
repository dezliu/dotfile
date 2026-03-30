" jj or jk 退出insert模式
inoremap jk <ESC>
inoremap jj <Esc>

" 显示行号 - 方便定位代码
set number
 
" 制表符宽度为 4 个空格
set tabstop=4
 
" 自动缩进 - 写代码时自动保持正确的缩进
set autoindent
 
" 启用鼠标支持 - 可以用鼠标选择、滚动等
set mouse=a
 
" 语法高亮 - 让代码五彩斑斓
syntax on
 
" 显示当前行号，其他行显示相对行号
set relativenumber
set number
 
" 将制表符转换为空格，保证跨编辑器格式统一
set expandtab
 
" 修复 Insert 模式下退格键失效问题
set backspace=indent,eol,start

" 高亮搜索结果
set hlsearch

" 输入搜索时实时跳转
set incsearch

" 忽略大小写（智能区分：当搜索包含大写字母时自动区分大小写）
set ignorecase
set smartcase
