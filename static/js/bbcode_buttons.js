
window.onload = function() {

// reguläre Ausdrücke
var liste 	= new RegExp(/\*([^*]+)/g);
var thread 	= new RegExp(/^http:\/\/.*\.perl-community\.de\/.*\/thread\/([\d]*)/);
var board 	= new RegExp(/^http:\/\/.*\.perl-community\.de\/.*\/board\/([\d]*)/);
var monks 	= new RegExp(/^http:\/\/perlmonks\.org\/.*node_id=([\d]*)/);
var url  	= new RegExp('^(http://|https://|www.|ftp://|mailto:).');

var help = {
liste: 'Listenformatierung!\n\nUm eine Liste zu erzeugen, markiere Text mit folgenden Format:\n\n* Liste\n*Liste\n*Liste',
url: 'Fügt eine Linkformatierung ein.',
noparse: 'Fügt einen Tag ein, innerhalb dessen BB-Code Tags nicht umgewandelt werden.'
};

// Elemente
var textarea = document.getElementsByTagName('textarea')[0];
var br = document.createElement("br");
if(!textarea || !br) return false;
	
var addTo = function(el) {br.parentNode.insertBefore(el, br);};
var group_margin = '1em';

// Zeilenumbruch einfügen
textarea.parentNode.insertBefore(br, textarea);
	
createButton(textarea, 'b', 'b', addTo);
createButton(textarea, 'i', 'i', addTo);
createButton(textarea, 's', 'strike', addTo);
createButton(textarea, 'tt', 'tt', addTo);
createButton(textarea, 'u', 'u', addTo);
createButton(textarea, 'Liste', 'liste', addTo);
createButton(textarea, 'noparse', null, addTo);
var morebutton = createButton(textarea, 'more', 'more', addTo);
morebutton.style.marginRight = group_margin;

createButton(textarea, 'Code', 'code', addTo);
createButton(textarea, 'Code(inline)', 'c', addTo);
createButton(textarea, 'Quote', 'quote', addTo);
createButton(textarea, 'Perl', 'perl', addTo).style.marginRight = group_margin;

createButton(textarea, 'Link', 'url', addTo);
createButton(textarea, 'msg', 'msg', addTo).title = 'Gib die Message-ID an';
createButton(textarea, 'thread', 'thread', addTo).title = 'Gib die Thread-ID an';
createButton(textarea, 'board', 'board', addTo).title = 'Gib die Board-ID an';
createButton(textarea, 'cpan search', 'cpan', addTo).title = 'Gib den Modulnamen für die CPAN-Suche an';
createButton(textarea, 'cpan modul', 'mod', addTo).title = 'Gib den Modulnamen für den CPAN-Link an';
createButton(textarea, 'pod', null, addTo).title = 'Gib die Perldoc-Seite für perldoc.perl.org an';
createButton(textarea, 'dist', null, addTo).title = 'Gib den Distributionsnamen für den CPAN-Direktlink an (z.B. Module-CoreList, mit Bindestrich!)';
createButton(textarea, 'wiki', null, addTo).title = 'Gib den WikiNamen an';
createButton(textarea, 'wikipedia', 'wp', addTo).style.marginRight = group_margin;


//createButton(textarea, 'perldoc', null, addTo).title = 'Gib den Bereich von PerlDoc an';

function createButton (element, text, tag, add) {
	if(!tag) tag = text;
	var button = document.createElement("input") || {};
	
    button.type = 'button';
	button.className = 'edit_button';
    button.value = text || '---';
    button.onclick = function() { insertTag(element, tag, this);  };
	if(add) add(button);
	if(help[tag]) button.title = help[tag];
	return button;
}

function insertTag(textarea, tag, button) {
    if(!textarea) return false;
	textarea.focus();
	
	function getSelection() {
		if(typeof document.selection != 'undefined') {
			var range = document.selection.createRange();
			return range.text;
		} else if(typeof textarea.selectionStart != 'undefined') {
			var start = textarea.selectionStart;
			var end = textarea.selectionEnd;
			return textarea.value.substring(start, end);
		}
		// Keine Funktion, um den ausgwählten Text zu ermitteln, verfügbar
		return window.prompt('Textinput:');
	}
    
	function insertText(t) {
		if(typeof document.selection != 'undefined') {
			
			var range = document.selection.createRange();
			range.text = t;
			if (t.length == 0) range.move('character', -1);
			else range.moveStart('character', t.length);
			
		} else if(typeof textarea.selectionStart != 'undefined') {
			
			var start = textarea.selectionStart;
			var end = textarea.selectionEnd;
			textarea.value = textarea.value.substr(0, start) + t + textarea.value.substr(end);
			var pos = start + t.length;
			textarea.selectionStart = pos;
			textarea.selectionEnd = pos;
			
		} else {
			textarea.value += t;
		}
	}
	
	// markierten Text ermitteln
	var t = getSelection();
	// Tagfunktion aufrufen
	var new_text = typeof TagList[tag] == 'function' ? 
		TagList[tag](tag, t, button) : 
		TagList.def(tag, t, button)
	;
	// Text einfügen
	insertText(new_text);
	return !!t;
}

/*
	insertTag.TagList
	Liste der Funktionen, die die BB Tags um den Text bauen
*/
var TagList = {
	wiki : function(tag, text, button) {
		if(!text) text = window.prompt(button.title);
		return this.def(tag, text, button);
	},
	wiki : function(tag, text, button) {
		if(!text) text = window.prompt(button.title);
		return this.def(tag, text, button);
	},
	perlmonk : function(tag, text, button) {
		if(!text) text = window.prompt(button.title);
		return this.def(tag, text, button, '=' + href);
	},
	perldoc : function(tag, text, button) {
		if(!text) text = window.prompt(button.title);
		return this.def(tag, text, button);
	},
	perl : function(tag, text, button) {
		var t = this.def('code', text, button, '=perl');
		button.value = button.value.replace(/code/, 'perl');
		return t;

	},
	liste: function(tag, t, button) {
		if(liste.test(t)){
			var ref = t.match(liste);
			var ret = '[list]';
			ref.forEach(function(el, i ){
				ret += '[*]' +el.substr(1);
			} );
			return ret + '[/list]';
		} else {
			alert(help.liste);
		}
		return t;
	},
	
	url: function(tag, t, button) {
		var text;
		var href;

		if(liste.test(t)){
			var ref = t.match(liste);
			var ret = '[list]';
			ref.forEach(function(el, i ){
				ret += '[*]' +el.substr(2);
			} );
			return ret + '[/list]';
			
		} else if(monks.test(t)){
			var ref = monks.exec(t);
			return '[perlmonks]' + ref[1] + '[/perlmonks]';
			
		} else if(board.test(t)){
			var ref = board.exec(t);
			return '[board]' + ref[1] + '[/board]';
			
		} else if( thread.test(t)  ) {
			var ref = thread.exec(t);
			return '[thread]' + ref[1] + '[/thread]';
		
		} else if( url.test(t)  ) {
			// Der Text ist ein Link
			href = t || window.prompt('URL eingeben:', '');
			text = window.prompt('Linktext eingeben:', '') || href;
			if (!url.test(href)) href = 'http://' + t;
		} else {
			// Der Text ist der Titel
			text = t || window.prompt('Linktext eingeben:', '');
			href = window.prompt('URL eingeben:', 'http://') || text;
			if (!url.test(href)) href = 'http://' + href;
		}
		return text && href ? this.def('url', text, button, '=' + href) :
		text ? text : '';
	},
	def: function(tag, t, b, attr) {
		// Wurde ein Text markiert => Tag drumherum
		var start = '[' + tag + (attr || '') + ']';
		var end = '[/' + tag + ']';
		if(t) return start + t + end;

		// kein markierter Text -> den Button kennzeichnen
		b.value = b.value.indexOf('/') > -1 ? b.value.substr(1) : '/' + b.value;
		return (b.value.indexOf('/') > -1) ? start : end;
	}
};

}; // END: anoyme Funktion

