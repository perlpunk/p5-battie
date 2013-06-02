function nodelet_toggle(what) {
    var el = document.getElementById('personal_nodelet');
    var el2 = document.getElementById('personal_nodelet_toggle');
    if (what == 'hide') {
        el.style.display = 'none';
        el2.style.display = 'inline';
    }
    else {
        el.style.display = 'inline';
        el2.style.display = 'none';
    }
}

my_call_nodelet = function() {
    document.getElementById('personal_nodelet').innerHTML = arguments[0];
}

function nodelet_add_url(theme_url, token, form) {
    var url = form.elements["nodelet.url"].value;
    var title = form.elements["nodelet.title"].value;
    var el = document.getElementById('personal_nodelet');
    el.innerHTML = '<img src="' + theme_url + '/wait.gif" width="50" height="10" alt="[wait]">';
    ajaxshow(
        ['ma__userprefs/personal_nodelet','submit.add__1','is_ajax__1','t__'+token,'nodelet.url__'+url,'nodelet.title__'+title ],
        [my_call_nodelet], 'POST' );
}

