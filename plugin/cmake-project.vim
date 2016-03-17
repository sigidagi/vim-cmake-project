"" vim-cmake-project
" Plugin provides list and navigation of project files on side bar with a help of NERDTree plugin 
" and command(s) for building cmake projects.
" Side bar shows only project related files: C/C++. ( NERDTree is filtered out )
" CMake command is deactivated and NERDTree structure is restored when CMakeLists.txt is removed from buffer.
"
" Last change: 2014 July 5 
" Maintainer: Sigitas Dagilis sigidagi@gmail.com
" License: BSD
"
" allow users to disable loading plugin by providing global variable.
" another reason - to avoid loading plugin twice.
if exists("g:loaded_cmake_project")
    finish
endif


" function first check for existence of specified option in .vimrc 
" keeping global option in dictionary for compactness, i.e later if options will grow
" it will be more convinient to keep in one place.
function! s:set_options()
    let s:options = {
    \  'g:cmake_project_show_bar':                1,
    \  'g:loaded_cmake_project':                  1,
    \  'g:cmake_project_build_directory':        'build',
    \  'g:cmake_project_generator':              'Unix Makefiles'
    \ }

    for aOption in keys(s:options)
        if !exists(aOption)
            let {aOption} = s:options[aOption]
        endif
    endfor
endfunction

function! s:init()
  augroup vim-cmake-project.vim
    au!
    au BufNewFile,BufRead CMakeLists.txt :call s:cmake_project_activate() 
    au BufDelete CMakeLists.txt :call s:cmake_project_deactivate()
    au BufDelete * :call s:cmake_project_opennext()
    au VimLeavePre * :call s:cmake_project_close_output()
  augroup END
endfunction

" Start ---------------------
let s:cmake_project_tmux_running = 0
call s:set_options()
call s:init()

function! s:cmake_project_remap()
   
    if !hasmapto('<Plug>CMakeCompile')
        map <unique> <Leader>pc <Plug>CMakeCompile 
    endif
    if !hasmapto('<Plug>CMakeClean')
        map <unique> <Leader>pl <Plug>CMakeClean 
    endif
    if !hasmapto('<Plug>CMakeBuild')
        map <unique> <Leader>pb <Plug>CMakeBuild
    endif

    noremap <script> <Plug>CMakeBuild :call <SID>cmake_project_build()<CR>
    noremap <script> <Plug>CMakeCompile :call <SID>cmake_project_compile()<CR>
    noremap <script> <Plug>CMakeClean :call <SID>cmake_project_clean()<CR>

endfunction

" Commands -------------------
" Check if buffers contains project file CMakeLists.txt. Deactivate commands if such
" file do not exist and vice versa. 
function! s:cmake_project_activate()
    
    command! -nargs=0 -complete=file CMakeBuild call s:cmake_project_build()
    command! -nargs=0 -complete=file CMakeCompile call s:cmake_project_compile()
    command! -nargs=0 -bar CMakeClean call s:cmake_project_clean()
    
    call s:cmake_project_checkplugins()
    call s:cmake_project_remap()
    
    let g:NERDTreeIgnore = ['\(\.txt\|\.cpp\|\.hpp\|\.c\|\.h\)\@<!$[[file]]']
    let s:cmake_project_source_directory = expand("<afile>:p:h")
    
    if !exists("t:NERDTreeBufName") && g:cmake_project_show_bar == 1 && exists('g:loaded_nerd_tree')
        call g:NERDTreeCreator.CreateTabTree(s:cmake_project_source_directory)
    endif
endfunction

function! s:cmake_project_warning(msg)
    echohl WarningMsg   
    echo a:msg
    echohl NONE
endfunction

function! s:cmake_project_checkplugins()
    " First should be loaded nerd-tree plugin. 
    if !exists('g:loaded_nerd_tree')
        call s:cmake_project_warning('[cmake-project] "NERD-Tree" plugin is needed for complete functionality')
    else
        command! -nargs=0 -bar CMakeBar call s:cmake_project_toggle_barwindow()
        if !hasmapto('<Plug>CMakeBar')
            map <unique> <Leader>pt <Plug>CMakeBar
        endif
        noremap <script> <Plug>CMakeBar :call <SID>cmake_project_toggle_barwindow()<CR>
    endif
    
    if !executable("tmux")
        call s:cmake_project_warning('[cmake-project] "tmux" installation is recommended for complete functionality')
        call s:cmake_project_warning('[cmake-project] After installation run "tmux" in a terminal and open project')
    elseif $TMUX == ""
        call s:cmake_project_warning('[cmake-project] Run "tmux" first, and then open project. You will thank me later.')
    else
        let s:cmake_project_tmux_running = 1
        command! -nargs=0 -bar CMakeOutput call s:cmake_project_close_output()
        if !hasmapto('<Plug>CMakeOutput')
            map <unique> <Leader>po <Plug>CMakeOutput
        endif
        noremap <script> <Plug>CMakeOutput :call <SID>cmake_project_close_output()<CR>
    endif
endfunction

function! s:cmake_project_jumptofile(path)
        let p = g:NERDTreePath.New(a:path)  "get the path to a file

        call g:NERDTreeFocus()              " change focus to nerd tree view
        call b:NERDTreeRoot.reveal(p)       " find that file on the tree 
        call g:nerdtree#invokeKeyMap("o")   " invoke open action
endfunction

function! s:cmake_project_opennext()

    if exists("t:NERDTreeBufName") && 
                \ bufwinnr(t:NERDTreeBufName) != -1 && 
                \ winnr("$") == 1 && 
                \ exists('g:loaded_nerd_tree')
        let blisted = filter(range(1, bufnr('$')), 'buflisted(v:val) && v:val != bufnr(expand("<afile>"))')
        let bjump = (blisted + [-1])[0]
        if bjump > 0
            call s:cmake_project_jumptofile(fnamemodify(bufname(bjump), ":p"))
        endif
    endif
endfunction

function! s:cmake_project_delcommands()
    delcommand CMakeBuild
    delcommand CMakeCompile
    delcommand CMakeClean
    if exists('g:loaded_nerd_tree')
        delcommand CMakeBar
    endif
    if $TMUX != "" 
        delcommand CMakeOutput
    endif
    let g:NERDTreeIgnore = []
endfunction

"  
function! s:cmake_project_close_output()
    if (s:cmake_project_tmux_running)
        call VimuxCloseRunner()
    endif
endfunction

function! s:cmake_project_deactivate() 

    if exists("t:NERDTreeBufName") && 
                \ bufwinnr(t:NERDTreeBufName) != -1 && 
                \ winnr("$") == 1 &&
                \ exists('g:loaded_nerd_tree')
        let choice = confirm(  
            \ "Closing CMakeLists.txt will close project. Are you sure?",
            \ "&Yes\n&No, return to project", 1) 
        if choice == 1
            call s:cmake_project_delcommands()
            quit
        endif 
        " Restore CMakeLists.txt by opening it again
        call s:cmake_project_jumptofile(expand("<afile>:p"))
    else 
        call s:cmake_project_delcommands()
    endif
endfunction

" Build project ---------- 
function! s:cmake_project_build() abort
    let build_directory = s:cmake_project_source_directory . "/" . g:cmake_project_build_directory

    if !isdirectory(build_directory)
        call mkdir(build_directory, "p")
    endif
    let command = "cmake -G\"" . g:cmake_project_generator . "\" -B" . build_directory . " -H" . s:cmake_project_source_directory 
    if s:cmake_project_tmux_running
        call VimuxRunCommand(command)
    else
        exec '!' .command 
    endif
endfunction

function! s:cmake_project_compile()
    let build_directory = s:cmake_project_source_directory . "/" . g:cmake_project_build_directory
    if !isdirectory(build_directory) || !filereadable(build_directory ."/Makefile")
        echo 'Run first :CMakeBuild command to create "Makefile"'
        return
    endif
    if s:cmake_project_tmux_running 
        call VimuxRunCommand('make -C' .build_directory)
    else
        exec '!make -C ' . build_directory
    endif
endfunction

function! s:cmake_project_clean()
    let build_directory = s:cmake_project_source_directory . "/" . g:cmake_project_build_directory
    if isdirectory(build_directory)
        if (s:cmake_project_tmux_running)
            call VimuxRunCommand('rm -rf ' .build_directory)
        else
            exec '!rm -rf ' . build_directory
            echo "build directory " . build_directory . " removed"
        endif
    endif
endfunction

" Toggle Bar window --------
function! s:cmake_project_toggle_barwindow() 
    if !exists("t:NERDTreeBufName") 
        call g:NERDTreeCreator.CreateTabTree(s:cmake_project_source_directory)
    else
        call g:NERDTreeCreator.TogglePrimary(s:cmake_project_source_directory)
    endif
endfunction

