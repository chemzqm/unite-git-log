# Unite-git-log

这是一个让你做为 vimer 可以感到自豪的插件，并不是说它本身多么优秀，而是它整合了或许是当今最好用的 vim 插件：

[Unite.vim](https://github.com/Shougo/unite.vim)  [fugitive.vim](https://github.com/tpope/vim-fugitive)

![git-log show]()


## 安装

推荐使用你熟悉的 vim 包工具进行安装，例如：[Vundle](https://github.com/gmarik/vundle)

.vimrc 中添加：

    Plugin 'Shougo/unite.vim'
    " vimproc 必须要，可能还需要执行 make， 请阅读官方说明: https://github.com/Shougo/vimproc.vim
    Plugin 'Shougo/vimproc'
    Plugin 'tpope/vim-fugitive'
    Plugin 'chemzqm/unite-git-log'

然后安装：

    :so ~/.vimrc
    :BundleInstall

## 使用

* 查找当前文件的所有提交记录

      :Unite gitlog

* 查找所有的提交记录

      :Unite gitlog:all

* 查找 5 天内的所有提交记录

      :Unite gitlog:all:5

* 命令映射(需自行添加到 .vimrc)：

      nnoremap <space>l :<C-u>Unite gitlog<cr>

你也可以通过 `g:unite_source_gitlog_default_opts` 来调整默认的 git log 命令选项，默认值为：

     --graph --no-color --pretty=format:'%h -%d %s (%cr) <%an>' --abbrev-commit --date=relative

修改可能会造成高亮无法正常显示。

## 主要快捷键

* `i`    进入编辑模式过滤记录
* `p`    预览窗口查看记录
* `d`    与当前文件执行 diff 操作
* `<cr>` 主窗口查看记录，可使用 fugitive 快捷键（例如 `gf` 进行跳转）
* `q`    退出


## MIT license
    Copyright (c) 2015 chemzqm@gmail.com
    
    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
