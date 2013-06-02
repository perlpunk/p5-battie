function approve_entry(form, id, div_id) {
    var res = document.getElementById(div_id);
    res.innerHTML = '<img src="' + theme + '/wait.gif" width="50" height="10" alt="[wait]">';
    form.elements["button_" + id].disabled = true;
    ajaxshow( ['ma__guest/approve_entry/'+id+'/','ajax__1',token,'submit.approve__1'], [div_id ], 'POST' );
}
function delete_entry(form, id, div_id) {
    var res = document.getElementById(div_id);
    res.innerHTML = '<img src="' + theme + '/wait.gif" width="50" height="10" alt="[wait]">';
    form.elements["delete_button_" + id].disabled = true;
    ajaxshow( ['ma__guest/delete_entry/'+id+'/','ajax__1',token,'submit.delete__1'], [div_id ], 'POST' );
}
function preview_entry(form) {
    var res = document.getElementById('preview');
    var name = form.elements["name"].value;
    if (!name) {
        alert("Please provide a name");
        return false;
    }
    var message = form.elements["message"].value;
    if (!message) {
        alert("Please provide a message");
        return false;
    }
    res.innerHTML = '<img src="' + theme + '/wait.gif" width="50" height="10" alt="[wait]">';
    ajaxshow( ['ma__guest/add','ajax__1',token,'submit.preview__1','name__'+form.elements["name"].value, 'email__'+form.elements["email"].value,'location__'+form.elements["location"].value,'url__'+form.elements["url"].value,'message__'+form.elements["message"].value,], ['preview' ], 'POST' );
}

