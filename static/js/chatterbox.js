var reload = 10000;
var count = 0;

function chatmsg2(form,from_chatterbox) {
	if (from_chatterbox) {
		from_chatterbox = 1;
	}
	else {
		from_chatterbox = 0;
	}
    var text = '';
var el = document.getElementById('wait_div');
el.innerHTML = '<img src="' + theme + '/wait.gif" width="50" height="10" alt="[wait]">';
    if (form) {
        text = form.elements["chat.msg"].value;
    }
	mycall = function() {
		place_result(form, arguments[1], arguments[2], from_chatterbox);
	};
    ajaxshow(
        ['ma__activeusers/chat','submit.send__1','is_ajax__1',token,'from_chatterbox__'+from_chatterbox,'chat.msg__'+text, 'chat.reload__' + reload, 'chat.count__' + count ],
        [ mycall ], 'POST' );

}

function place_result(form, result, reload_info, from_chatterbox) {
	if (form) {
		empty_textfield(form);
	}
	document.getElementById('chatterbox').innerHTML = result;
	var el = document.getElementById('wait_div');
	el.innerHTML = '';
    var end = document.getElementById('end');
    end.scrollIntoView(true);

	if (!from_chatterbox)
		return;
	if (reload_info.match(/(\d+):(\d+)/)) {
		reload = RegExp.$1;
		count = RegExp.$2;
	}
	else {
		reload = 0;
		count = 1;
	}
	if (!form) {
		// reload
		start_reload();
	}
	else {
		if (reload == 0) {
			reload = 10000;
			count = 0;
			start_reload();
		}
		else {
			reload = 10000;
			count = 0;
		}
	}
	if (reload > 0) {
		document.getElementById('info_reload').innerHTML = reload / 1000;
	}
	else {
		document.getElementById('info_reload').innerHTML = "-";
	}
}
function empty_textfield(form) {
	form.elements["chat.msg"].value = "";
}

function start_reload() {
    if (reload > 1000) {
        window.setTimeout(
            function() { chatmsg2(false,1) },
            reload
        );
    }
}


