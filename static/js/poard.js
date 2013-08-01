var thread_overview_active = 0;

var name_unsub = 'submit.unsubscribe';
var name_sub = 'submit.subscribe';
function subscribe_thread2 () {
    var args = subscribe_thread2.arguments;
	var id = args[0];
    var title_unsub = args[1];
    var label_unsub = args[2];
    var title_sub   = args[3];
    var label_sub   = args[4];
	var toggle;
	var button = document.getElementById('sub');
	document.getElementById('result_subscribe').innerHTML = 
		'<img src="' + theme + '/wait.gif" width="50" height="10" alt="[wait]">';

    var current_name = button.name;
    if (current_name == 'submit.subscribe') {
        toggle = 'subscribe';
        button.title = title_unsub;
        button.name = name_unsub;
        button.value = label_unsub;
    }
    else {
        toggle = 'unsubscribe';
        button.title = title_sub;
        button.name = name_sub;
        button.value = label_sub;
    }
    ajaxshow(
		['ma__poard/subscribe_thread/'+id,'submit.'+toggle+'__1','is_ajax__1',token],
		'result_subscribe', 'POST'
	);
}


var current;
function admin_toggle_label(id) {
    var label = document.getElementById("board_label_" + id);
    var radio = document.getElementById("board_radio_" + id);
    if (radio.checked == true) {
        label.className = 'board_label_selected';
        if (current) {
            current.className = 'board_label';
        }
        current = label;
    }
}

function hide_message_static(id) {
    var limg_remove = theme + '/remove.png';
    var limg_show = theme + '/icons/plus.png';
    var image = document.getElementById('collapse_' + id);
    var table = document.getElementById('div_msg_' + id);
	if (table == null)
		return;
    if (table.style.display == 'none') {
        image.src = limg_remove;
        image.alt = 'collapse';
        image.title = 'collapse';
        table.style.display = 'block';
        table.battie_hidden = false;
    }
    else {
        image.src = limg_show;
        image.alt = 'open';
        image.title = 'open';
        table.style.display = 'none';
        table.battie_hidden = true;
    }
    if (thread_overview_active)
        draw_outline();
}
function hide_all(hide) {
    for (var i in messages) {
        var id = messages[i];

        var table = document.getElementById('div_msg_' + id);
        /* Skip tables that are already in the desired state */
        if (table && hide == table.battie_hidden)
            continue;

        /* Toggle hidden state */
        hide_message_static(id);
    }
}

function hide_old_branches(hide) {
    for (var i in old_branches) {
        var id = old_branches[i];
        hide_subtree(id, hide);
    }
}

function hide_subtree(id, hide) {
    var tree = document.getElementById('tree_' + id);
    var li = document.getElementById('li_' + id);
    var really_hide = tree.className != "tree_info_show";
    if (hide_subtree.arguments.length == 2) {
        really_hide = hide;
    }
    if (really_hide == false) {
        tree.className = "tree_info_hidden";
        li.className = "message_tree";
    }
    else {
        tree.className = "tree_info_show";
        li.className = "message_tree_hidden";
    }
}

/* moderation */
function approve_message(id, div_id) {
    var res = document.getElementById(div_id);
    res.innerHTML = '<img src="' + theme + '/wait.gif" width="50" height="10" alt="[wait]">';
    ajaxshow( ['ma__poard/approve_message/'+id+'/','ajax__1',token,'submit.approve__1'], [div_id ], 'POST' );
}
function delete_message(id, div_id,del_id) {
    var el = document.getElementById(del_id);
    el.style.visibility = 'visible';
    return;
}
function cancel_delete_message(id, div_id,del_id) {
    var el = document.getElementById(del_id);
    el.style.visibility = 'hidden';
}
function really_delete_message(id, div_id,del_id, id) {
    var el = document.getElementById(del_id);
    var reason = document.getElementById('del_reason_'+id);
    var other = document.getElementById('other_reason_'+id);
    var comment = reason.value;
    if (other.value) {
        comment += ' '+ other.value;
    }
    el.style.visibility = 'hidden';
    var res = document.getElementById(div_id);
    res.innerHTML = '<img src="' + theme + '/wait.gif" width="50" height="10" alt="[wait]">';
    ajaxshow( ['ma__poard/mod_delete_message/'+id,'ajax__1','submit.reallydelete__1',token,'comment__'+comment], [div_id ], 'POST' );
}
function refresh_list(latest_time) {
	var div_id = 'result_list';
    var res = document.getElementById('javascript');
    res.innerHTML = '<img src="' + theme + '/wait.gif" width="16" height="16" alt="[wait]">';
    ajaxshow( ['ma__poard/latest/' + latest_time,'is_ajax__1',token,'submit.refresh__1'], [div_id ], 'POST' );
}

function loadmore2(arrow,msid, counter) {
    var res = document.getElementById('more_'+msid+'_'+counter);
    res.innerHTML = '<img src="' + theme + '/wait.gif" width="50" height="10" alt="[wait]">';
    my_call_loadmore = function() {
        res.innerHTML = '<div class="loadmore_header">' + arguments[0] + '</div>';

        arrow.onclick = function() {
            toggle_more(arrow, res);
        };
        arrow.src = theme+'/arrow_up.png';

    }
    ajaxshow(
        ['ma__poard/message/'+msid,'more_id__'+counter,'is_ajax__1'],
        [my_call_loadmore], 'GET'
    );
}

function toggle_more(arrow, more_div) {
    var style = more_div.style;
    if (style.display == 'none') {
        style.display = '';
        arrow.src = theme+'/arrow_up.png';
    }
    else {
        style.display = 'none';
        arrow.src = theme+'/arrow_down.png';
    }
}

function write_toggle(div_id) {
    document.write('<img src="'+theme+'/arrow_up.png" alt="more" style="vertical-align: bottom;cursor:pointer" onclick="toggle_more(this, document.getElementById(\''+div_id+'\'));">');
}

function write_loadmore(msid, counter) {
    document.write('<img src="'+theme+'/arrow_down.png" alt="more" style="vertical-align: bottom;cursor: pointer" onclick="loadmore(this,'+msid+','+counter+')" title="show hidden content inline">');
    document.write('<div id="more_'+msid+'_'+counter+'"></div>');
}

function write_markup_help(div_id, div_id2) {
    document.write(
    '<img src="'+theme+'/arrow_down.png" title="Show markup help inline" onclick="call_markup_help(\''+div_id+'\');return false;" style="cursor:pointer;"'
    + ' onmouseover="markup_teaser(true,\''+div_id2+'\')"'
    + ' onmouseout="markup_teaser(false,\''+div_id2+'\')" >');
}
function markup_teaser(on,div_id) {
    var teaser = document.getElementById(div_id);
    if (teaser != null) {
        if (on == true) {
            teaser.style.border="1px dotted orange";
            teaser.innerHTML = "Show markup help here";
        }
        else {
            teaser.style.border="0px dotted orange";
            teaser.innerHTML = "";
        }
    }
}

function call_markup_help(div_id) {
    document.getElementById(div_id).innerHTML = 
        '<img src="' + theme + '/wait.gif" width="50" height="10" alt="[wait]">';
    var res = document.getElementById(div_id);
    my_call_markup_help = function() {
        res.innerHTML = arguments[0];
        res.style.overflow = 'scroll';
    }
    ajaxshow( ['ma__poard/markup_help/','is_ajax__1'], [my_call_markup_help], 'GET' );
}

function change_size(num, which) {
    if (which == 'width') {
        var cols = document.getElementsByName('settings.textarea.cols')[0];
        var new_val = 0;
        if (num != 0) {
            new_val = parseInt(cols.value) + num;
            cols.value = new_val;
        }
        else {
            new_val = document.getElementsByName('settings.textarea.cols')[0].value;
        }
        document.getElementsByName('texarea.dummy')[0].cols = new_val;
    }
    else if (which == 'height') {
        var rows = document.getElementsByName('settings.textarea.rows')[0];
        var new_val = 0;
        if (num != 0) {
            new_val = parseInt(rows.value) + num;
            rows.value = new_val;
        }
        else {
            new_val = document.getElementsByName('settings.textarea.rows')[0].value;
        }
        document.getElementsByName('texarea.dummy')[0].rows = new_val;
    }
}

function select_tag(input, name, index) {
    var cont = document.getElementById('tag_container');
    var tags = cont.getElementsByTagName('input');
    var tag_div = document.getElementById('tags_' + name);
    var found = false;
    var parent = input.parentNode;
    for (var i=0; i<tags.length; i++) {
        var value = tags[i].value;
        if (! value.length) {
            var clone = tags[i].cloneNode(true);
            clone.value = input.value;
            var br = document.createElement('br');
            cont.insertBefore(br,tags[i]);
            cont.insertBefore(clone,br);
            tag_div.removeChild(parent);
            break;
        }
        else if (value == input.value) {
            alert('Duplicate tag');
            tag_div.removeChild(parent);
            break;
        }
    }
}

var selected_tag;
var tag_cache = new Array();
var tags_template;
var tag_container = new Array();
var active_num = -1;
var suggestions_active_1 = false;
var suggestions_active_2 = false;

function suggestions(box, e) {
    if (!e) {
        e = window.event ;
    }
    var k = e.charCode || e.keyCode;
    if (k == 40 || k == 38) {
        return;
    }
    selected_tag = box;
    var tagsearch = box.value;
    var result = document.getElementById('result_tag_suggest');
    if (tagsearch.length > 0) {
        suggestions_active_1 = true;
        var in_cache = tag_cache[tagsearch];
        if (in_cache) {
            var res = create_tag_list(in_cache, tags_template, tag_container);
            result.innerHTML = res;
            listener(box, result);
            return;
        }
        my_call_suggest = function() {
            result.innerHTML = '';
            var object = JSON.parse(arguments[3]);
//            alert(object);
            var has_more = object.has_more;
            tag_container['header'] = arguments[1];
            tag_container['footer'] = arguments[2];
            tags_template = arguments[0];
            var tags = object.list;
            tag_cache[tagsearch] = object;
            var res = create_tag_list(object, tags_template, tag_container);
            result.innerHTML = res;

            listener(box, result);
        }
        ajaxshow(
            ['ma__poard/tag_suggest', 'tag__'+tagsearch,'is_ajax__1'],
            my_call_suggest, 'GET'
        );
    }
//    var debug = document.getElementById('result_tag_suggest_debug');

    return true;
}

function listener(box, result) {
    no_default(box, 'keydown');
    no_default(box, 'keypress');
    var select = document.getElementById('tag_suggest_box');

    box.addEventListener('keydown', function(e){
        e= window.event || e;
        var k = e.charCode || e.keyCode;
        if (k == 40) {
            box.removeEventListener('keydown', arguments.callee, true);
            box.removeEventListener('keydown', prevent_default_listener, false);
            box.removeEventListener('keypress', prevent_default_listener, false);
            select.focus();
        }
        return true;
    }, true);
}

function try_take_suggestion(value, e) {
    e= window.event || e;
    var k = e.charCode || e.keyCode;
    if (k == 13) {
        e.preventDefault();
        take_tag_suggestion(value);
    }
}

function no_default(box, action) {
    box.addEventListener(action, prevent_default_listener, false);
}

function prevent_default_listener(e) {
    var k = e.charCode || e.keyCode;
    if (k == 40 || k == 38) {
        e.preventDefault();
    }
}

function create_tag_list(object, template, tag_container) {
    var tags = object.list;
    var size = object.size;
    var result = tag_container['header'];
    result = result.replace(/SUGGESTION_SIZE/g, size);
    for (var i=0; i<tags.length; i++) {
        var temp = template;
        var res = temp.replace(/SUGGESTION_NAME/g, tags[i].name);
        res = res.replace(/SUGGESTION_COUNT/g, tags[i].count);
        result += res;
    }
    result += tag_container['footer'];
    return result;
}

function take_tag_suggestion(span) {
    var text = span;
    selected_tag.value = text;
    var result = document.getElementById('result_tag_suggest');
    suggestions_active_2 = false;
    close_suggestions(suggestions_active_1);
}

function close_suggestions(from) {
    if (from == 1) {
        suggestions_active_1 = false;
        selected_tag.removeEventListener('keydown', prevent_default_listener, false);
        selected_tag.removeEventListener('keypress', prevent_default_listener, false);
    }
    else {
        suggestions_active_2 = false
    }
//    var debug = document.getElementById('result_tag_suggest_debug');
    var result = document.getElementById('result_tag_suggest');
    if (result.innerHTML.length > 0) {
        window.setTimeout(
            function() {
                really_close_suggestions();
             },
            500
        );
    }
}
function active_suggestions(from) {
//    var debug = document.getElementById('result_tag_suggest_debug');
    if (from == 1) {
        suggestions_active_1 = true;
    }
    else {
        suggestions_active_2 = true;
    }
}
function really_close_suggestions() {
    var result = document.getElementById('result_tag_suggest');
    if (suggestions_active_1 == false && suggestions_active_2 == false ) {
        result.innerHTML = '';
    }

}

var poard_autosave_article = 'poard_autosave_articles5';
function init_autosave_article() {
    if (sessionStorage) {
        var autosave_articles = sessionStorage.getItem(poard_autosave_article);
        if (! autosave_articles) {
            autosave_articles = new Object;
            var string = JSON.stringify(autosave_articles);
            sessionStorage.setItem(poard_autosave_article, string);
        }
    }
}
function autosave_article(thread_id, msg_id) {
    if (sessionStorage) {
        var key = thread_id+':'+msg_id;
        var autosave_articles = sessionStorage.getItem(poard_autosave_article);
        autosave_articles = JSON.parse(autosave_articles);
        var form = document.getElementById('post_answer_form');
        var autosave_msg = new Object;
        var epoch = Math.floor(new Date().valueOf() / 1000);
        autosave_msg.message = form.elements["message.message"].value;
        autosave_msg.time = epoch;
        var title = document.getElementById("thread_title_link").innerHTML;
        autosave_msg.thread_title = title;

        autosave_articles[key] = autosave_msg;
        var string = JSON.stringify(autosave_articles);
        sessionStorage.setItem(poard_autosave_article, string);
    }
}
function fill_saved_article(thread_id, msg_id) {
    if (sessionStorage) {
        var key = thread_id+':'+msg_id;
        var autosave_articles = sessionStorage.getItem(poard_autosave_article);
        autosave_articles = JSON.parse(autosave_articles);
        var autosave_msg = autosave_articles[key];
        if (autosave_msg) {
            var form = document.getElementById('post_answer_form');
            var input = form.elements["message.message"];
            if (input.value.length < 1) {
                input.value = autosave_msg.message;
                var hint = document.getElementById('autofill_hint');
                var date = new Date(autosave_msg.time * 1000);
                hint.innerHTML = 'Autosaved article from '+ date;
            }
        }
    }
}
function display_drafts() {
    if (sessionStorage) {
        var autosave_articles = sessionStorage.getItem(poard_autosave_article);
        autosave_articles = JSON.parse(autosave_articles);
        var box = document.getElementById('draftlist_box');
        var list = document.getElementById('draftlist');
        var first = list.getElementsByTagName("li");
        for (var key in autosave_articles) {
            var keys = key.split(":");
            var thread_id = keys[0];
            var msg_id = keys[1];
            var draft = autosave_articles[key];
            var string = JSON.stringify(draft);
            var title = draft.thread_title;
            var newlink = first[0].cloneNode(true);
            var text = newlink.innerHTML + '';
            text = text.replace(/TITLE/g, title);
            text = text.replace(/THREAD_ID/g, thread_id);
            var date = new Date(draft.time * 1000);
            text = text.replace(/TIME/g, date);
            newlink.innerHTML = text;
            newlink.setAttribute('style', 'display: block');
            list.appendChild(newlink);
        }
        var style = box.getAttribute('style');
        style = style.replace(/none/, 'block');
        style = style.replace(/-99/, '99');
        box.setAttribute('style', style);
    }
}

function create_nested_list(id, html) {
    var ul = $('<ul id="overview_ul_'+id+'" />');
    var li = $('<li id="overview_li_'+id+'"/>');
    var posting = $('<div id="overview_' + id + '" />');
    var f = createClosure(id);
    $(ul).append(li);
    $(li).append(posting);
    $(posting).click(f);
    var posting_orig = $('#li_' + id).find('div.posting:first');
    var author = $('#li_' + id).find('.author:first');
    var headline = $('#li_' + id).find('.posting_headline');
    $(posting).append(author.text());
    $(posting).attr('class', $(headline).attr('class'));
    if ($(posting_orig).hasClass('unread_msg')) {
        $(posting).addClass('unread_msg');
    }
    $(html).append(ul);
    var ul_original = $('#ul_' + id);
    var links = $(ul_original).find('> li.message_tree');
    for (var i = 0; i < links.length; i++) {
        var link = links[i];
        var link_id = $(link).attr('id');
        if (link_id.match(/li_(\d+)/)) {
            var new_id = RegExp.$1;
            create_nested_list(new_id, ul);
        }
    }
}

function createClosure(i) {
    var f = function() {
        $('html, body').animate({
            scrollTop: $("#li_"+i).offset().top
        }, 500, null, function() { draw_outline() });
    };
    return f;
}
function draw_outline() {
    var links = $('.message_tree_root').find('li.message_tree');
    $('#thread_overview_outline').text('');
    var outline_top = 0;
    var outline_height = 0;
    var scrolltop = $(document).scrollTop();
    var scrollbottom = scrolltop + window.innerHeight;
    var overview_scrolltop = $('#thread_overview').scrollTop();
    for (var i = 0; i < links.length; i++) {
        var li = links[i];
        id = $(li).attr('id');
        if (id.match(/li_(\d+)/)) {
            id = RegExp.$1;
        }
        var top_offset = $(li).offset().top;
        if (scrolltop > top_offset) {
        }
        else if (outline_top == 0) {
            var overview_li = $('#overview_li_' + id);
            var f = overview_li.offset().top - $('#thread_overview').offset().top;
            outline_top = f;
            outline_top = f + overview_scrolltop;
        }
        else {
            if (scrollbottom < top_offset) {
                var overview_li = $('#overview_li_' + id);
                var f = overview_li.offset().top - $('#thread_overview').offset().top;
                var height = f - outline_top;
                outline_height = height + overview_scrolltop;
                break;
            }
        }
    }
    $('#thread_overview_outline').css({ top: outline_top + 'px'});
    if (outline_height == 0) {
        outline_height = $('#thread_overview').height() - outline_top + overview_scrolltop;
    }
    $('#thread_overview_outline').css({ height: outline_height-2 + 'px'});
}
function toggle_overview() {
    activate_overview();
    var toggle_button = $('#toggle_overview');
    var open = $(toggle_button).attr('data-open');
    var ul = $('#thread_overview').find('ul:first');
    var thread_navi_status = 0;
    if (open == 1) {
        thread_navi_status = 0;
        $(toggle_button).attr('data-open', 0);
        $('#thread_overview').animate({
            width: 'hide'
        }, 200);
        $(toggle_button).attr('src', theme+'/icons/arrow-skip.png');
    }
    else {
        thread_navi_status = 1;
        $(toggle_button).attr('data-open', 1);
        $('#thread_overview').animate({
            width: 'show'
        },
        200, null, function() {
            draw_outline();
            $(toggle_button).attr('src', theme+'/icons/arrow-skip-180.png');
        });
    }
    if (! localStorage)
        return;
    localStorage.setItem('poard_thread_navi_status', thread_navi_status);
}

var d_height = window.innerHeight;
function create_thread_overview() {
    if (! localStorage)
        return;
    var thread_navi_status = localStorage.getItem('poard_thread_navi_status');
    if (thread_navi_status == null)
        thread_navi_status = 1;

    var links = $(document).find('li.message_tree');
    if (links.length < 4) {
        return;
    }
    var overview = $('<div id="thread_overview" >Navi</div>');
    var settings_button = $('<div style="float: left;"><img src="'+theme+'/settings.png" border="0" alt="" style="cursor: pointer;"></div>');
    var outline = $('<div id="thread_overview_outline" />');
    var toggle_div = $('<div id="thread_overview_toggle_div" ></div>');
    var toggle_button = $('<img rc="'+theme+'/icons/arrow-skip-180.png" data-open="1" id="toggle_overview" nclick="toggle_overview();" style="padding: 5px;">');

    $('body').append(overview);
    $(overview).append(settings_button);
    $(settings_button).find('img').click(function() { toggle_overview_settings() });
    var shortcut_toggle = localStorage.getItem('poard_thread_navi_shortcut_toggle');
    var settings = $('<div id="overview_settings" style="display: none; position: absolute; background-color: white; border: 1px solid black;">Shortcut for Navi:<br>'
    +'toggle: CTRL-<input type="text" size="2" maxlength="1" value="'+shortcut_toggle+'" id="overview_shortcut_toggle"><br>'
    +'<button onclick="save_overview_shortcuts()">Save</button></div>');
    $(settings_button).append(settings);
    $(overview).append(outline);
    $(toggle_div).append(toggle_button);
    $(toggle_button).click(function() { toggle_overview() });
    $('body').append(toggle_div);
    $(toggle_div).css({ top: d_height/2 + 'px' });
    if (thread_navi_status == 1) {
        $(toggle_button).attr('src', theme+'/icons/arrow-skip-180.png');
        activate_overview();
    }
    else {
        $(toggle_button).attr('data-open', 0);
        $(toggle_button).attr('src', theme+'/icons/arrow-skip.png');
    }
    create_overview_shortcut_event(shortcut_toggle);
}
function create_overview_shortcut_event(shortcut_toggle) {
    if (shortcut_toggle != null && shortcut_toggle.length) {
        var code_open = shortcut_toggle.charCodeAt(0);
        $(window).keydown(function(event) {
            if(event.ctrlKey && event.keyCode == code_open) {
                event.preventDefault();
                toggle_overview();
            }
        });
    }
}

function toggle_overview_settings(set) {
    if (set == null) {
        if ($('#overview_settings').css('display') == 'none') {
            set = 1;
        }
        else {
            set = 0;
        }
    }
    if (set == 1) {
        $('#overview_settings').show(100);
    }
    else {
        $('#overview_settings').hide(100);
    }
}

function save_overview_shortcuts() {
    var shortcut_toggle = $('#overview_shortcut_toggle').val();
    if (shortcut_toggle.length) {
        localStorage.setItem('poard_thread_navi_shortcut_toggle', shortcut_toggle.toUpperCase());
        create_overview_shortcut_event(shortcut_toggle);
    }
    else {
        localStorage.setItem('poard_thread_navi_shortcut_toggle', '');

    }
}

function activate_overview() {
    if (thread_overview_active)
        return;
    create_nested_list(first_id, $('#thread_overview'));
    draw_outline();
    $('#thread_overview').scroll(function() {
        draw_outline();
    });
    $(window).scroll(function() {
        draw_outline();
    });
    thread_overview_active = 1;
    var o_height = $('#thread_overview').height();
    var offset_top = d_height/2 - o_height/2;
    $('#thread_overview').css({ top: offset_top + 'px' });
}

