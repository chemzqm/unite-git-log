# Unite-git-log

使用 unite 界面与 gitlog 进行交互

[Unite.vim](https://github.com/Shougo/unite.vim)

![git-log](http://7jpox4.com1.z0.glb.clouddn.com/gitlog.gif)

http://7jpox4.com1.z0.glb.clouddn.com/gitlog.gif

**注意** 新版使用[easygit](https://github.com/chemzqm/easygit),
如不想安装新插件，可使用调用 fugitive 插件的 tag 0.1.0

## 更新

2016-01-08
* 新版去除了 `fugitive` 依赖，使用更为友好的 [easygit](https://github.com/chemzqm/easygit)
* 添加了 vim 文档

2016-01-06
* 添加了 reset 操作
* 添加了默认 edit 操作内 quit 和 diff 的快捷键 `q` 和 `d`

## 安装

推荐使用你熟悉的 vim 包工具进行安装，例如：[Vundle](https://github.com/gmarik/vundle)

.vimrc 中添加：

    Plugin 'Shougo/unite.vim'
    " vimproc 必须要，可能还需要执行 make， 请阅读官方说明: https://github.com/Shougo/vimproc.vim
    Plugin 'Shougo/vimproc'
    Plugin 'chemzqm/easygit'
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

* 映射参考：(需自行添加到 .vimrc)：

```
call unite#custom#profile('gitlog', 'context', {
  \  'start_insert': 0,
  \  'no_quit': 1,
  \  'vertical_preview': 1,
  \ })
nnoremap <silent> <space></space>l  :<C-u>Unite -buffer-name=gitlog   gitlog<cr>
```

你也可以通过 `g:unite_source_gitlog_default_opts` 来调整默认的 git log 命令选项，默认值为：

     --graph --no-color --pretty=format:'%h -%d %s (%cr) <%an>' --abbrev-commit --date=relative

修改可能会造成高亮无法正常显示。

## 主要快捷键

* `i`    进入编辑模式过滤记录
* `p`    预览窗口查看记录
* `d`    与当前文件执行 diff 操作
* `<cr>` 主窗口查看记录，可使用 fugitive 快捷键（例如 `gf` 进行跳转）
* `q`    退出当前窗口


## MIT license
