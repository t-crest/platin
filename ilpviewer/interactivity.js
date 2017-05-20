function loadJSON(file, callback) {
	var xobj = new XMLHttpRequest();
	xobj.overrideMimeType("application/json");
	xobj.open('GET', file, true); // Replace 'my_data' with the path to your file
	xobj.onreadystatechange = function () {
		if (xobj.readyState == 4 && xobj.status == "200") {
			// Required use of an anonymous callback as .open will NOT
			// return a value but simply returns undefined in asynchronous
			// mode
			callback(JSON.parse(xobj.responseText));
		}
	};
	xobj.send(null);
}

function resolve(container) {
	// Fuck error checking the resolving. If there is no svg, we can die anyways...
	var svg = document.getElementById(container).contentDocument.getElementsByTagName("svg")[0];
	return svg;
}

function escapeHtml(str) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
}

function add_svg_stylesheet(svgdoc, cssfile) {
	var linkElm = svgdoc.createElementNS("http://www.w3.org/1999/xhtml", "link");
	linkElm.setAttribute("href", cssfile);
	linkElm.setAttribute("type", "text/css");
	linkElm.setAttribute("rel",  "stylesheet");
	var svg = svgdoc.getElementsByTagName("svg")[0];
	svg.insertBefore(linkElm, svg.childNodes[0]);
}

var svg         = null;
var constraints = null;

function generateVariableToken(tok, variable, colourmap) {
	var span = document.createElement("span");
	span.setAttribute("class", "formulavariable");
	span.setAttribute("data",  variable.id);
	span.appendChild(document.createTextNode(tok));
	span.onclick = function() {showConstraintsForNode(variable.id);};
	var colour = colourmap[variable.id];
	span.setAttribute("style", "background-color:" + colour.fill + ";border-color: "+colour.stroke+";");
	//span.style.backgroundColor = colour.fill;
	//span.style.color           = colour.stroke;
	return span;
}

// https://stackoverflow.com/questions/37128624/terse-way-to-intersperse-element-between-all-elements-in-javascript-array
function intersperse(a, delim) {
	return [].concat(...a.map(e => [document.createTextNode(delim), e])).slice(1)
}

// http://stackoverflow.com/a/2450976
function shuffle(array) {
	var currentIndex = array.length, temporaryValue, randomIndex;

	// While there remain elements to shuffle...
	while (0 !== currentIndex) {

			// Pick a remaining element...
			randomIndex = Math.floor(Math.random() * currentIndex);
			currentIndex -= 1;

			// And swap it with the current element.
			temporaryValue = array[currentIndex];
			array[currentIndex] = array[randomIndex];
			array[randomIndex] = temporaryValue;
	}

	return array;
}

// Generate a (randomized yet deterministic) set of colors
function genColors(nc) {
	var colors = [];

	for(var i = 0; i < nc; i++) {
		// hsl: Hue, Saturation, Lightness
		var col = i * (360 / nc) % 360;
		colors.push({
			fill:   "hsl(" + col + ", 100%, 80%)",
			stroke: "hsl(" + col + ", 100%, 40%)",
		});
	}

	Math.seedrandom(42); // I want repeatable colors.
	colors = shuffle(colors);

	return colors;
}

// We want to make the mark the variables in the formula
// and color them accordingly
//   - formula:   is the formula
//   - vars:      List of variables for identificatino
//   - colourmap: hash from variableid to colour
function tokenizeFormula(formula, vars, colourmap) {
	// Build a hash
	var vh = {};
	vars.map(function(v) {
		vh[v.name] = v;
	});

	// dead simple tokenisation
	var toks = formula.split(" ");
	var etoks = toks.map(function (tok) {
		if(tok in vh) {
			// token is a variable
			return generateVariableToken(tok, vh[tok], colourmap);
		} else {
			// token is something else
			return document.createTextNode(tok);
		}
	});

	// Join with a space
	var frag = document.createDocumentFragment();
	var nodes = intersperse(etoks, "\u00a0");
	nodes.map(function (n) {
		frag.appendChild(n);
	});
	return frag;
}

// Generate a colour mapping
function colourConstraintVariables(cons) {
	// collect all variables from the relevant constraints
	var vars = {};
	cons.map(function (ci) {
		constraints.c2v[ci].map(v => vars[v.id] = 1);
	});

	// now fuse with colours
	var keys = Object.keys(vars);
	var cols = genColors(keys.length);
	for(var i = 0; i < keys.length; i++) {
		vars[keys[i]] = cols[i];
	}

	return vars;
}

// Show the list of constraint-ids in the constraint list window
function showConstraints(cons) {
	// Clear the current contraintslist
	var clist = document.getElementById("constraintlist");
	clist.innerHTML = "";

	var colormap = colourConstraintVariables(cons);

	// Add all the relevant constraints
	cons.map(function (ci) {
		var c     = constraints.constraints[ci];
		var entry = document.createElement("li");
		var vars  = constraints.c2v[ci];
		entry.appendChild(tokenizeFormula(c.formula, vars, colormap));
		entry.setAttribute("title", c.name)
		clist.appendChild(entry);
	});

	return colormap;
}

function scrollIntoView(element) {
	var scrollparent = document.getElementById('ilpcanvas').parentNode;
	var svgbb = element.getBBox();

	scrollparent.scrollTop  = svg.scrollHeight + svgbb.y - svgbb.height/2 - scrollparent.clientHeight/2;
	scrollparent.scrollLeft = svg.scrollWidth  - svgbb.x - svgbb.width/2 - scrollparent.clientWidth/2;
}

function showConstraintsForNode(nodename) {
	var id = nodename;
	var cons = constraints.v2c[id];

	var colmap = showConstraints(cons);
	colourizeNodes(colmap);

	// We want to focus on the clicked element
	var elem = svg.getElementById(id);
	setAttr(elem, "stroke-width", "6px");
	// false means it does not have to align with top
	//elem.scrollIntoView({block: "start", behavior: "smooth"});
	scrollIntoView(elem);
}

function hasClass(element, cls) {
    return element.classList.contains(cls);
}

// Query root for multiple tagtypes
function getElementsByTagList(root, list) {
	var elems = [];
	list.map(function (tag) {
		var htmls = root.getElementsByTagName(tag);
		// Weird language... we have to convert a list to a ... list...
		var array = Array.prototype.slice.call(htmls, 0);
		elems = elems.concat(array);
	});
	return elems;
}

var undolog = [];
// Change and log
function setAttr(elem, attribute, newval) {
	// Construct undoinformation
	var ui = {
		elem: elem,
		attr: attribute,
		data: elem.getAttribute(attribute),
	};
	undolog.push(ui);
	elem.setAttribute(attribute, newval);
}

// process the undolog (back to the front, you shall see...)
function undo() {
	for (var i = undolog.length - 1; i >= 0; i--) {
		var ui = undolog[i];
		ui.elem.setAttribute(ui.attr, ui.data);
	}
	undolog = [];
}

// Colourize nodes
function colourizeNodes(colourmap) {
	undo();
	Object.keys(colourmap).map(function (nid) {
		colourSVGElement(nid, colourmap[nid]);
	});
}

// Highlight an svg element, emitting an undolog
function colourSVGElement(nid, colourinfo) {
	var elem = svg.getElementById(nid);
	if (hasClass(elem, 'edge')) {
		// Set the color for the edge-label
		setAttr(elem, "fill", colourinfo.stroke);

		// Arrowhead
		var p = elem.getElementsByTagName("polygon");
		for (var i = 0; i < p.length; i++) {
			setAttr(p[i], "fill",   colourinfo.stroke);
			setAttr(p[i], "stroke", colourinfo.stroke);
		}

		// Arrowtail
		var p = elem.getElementsByTagName("path");
		for (var i = 0; i < p.length; i++) {
			setAttr(p[i], "stroke", colourinfo.stroke);
		}
	} else if (hasClass(elem, 'node')) {
		var p = getElementsByTagList(elem, ['polygon', 'ellipse']);
		//var p = elem.getElementsByTagName("polygon");
		for (var i = 0; i < p.length; i++) {
			// Border
			setAttr(p[i], "stroke", colourinfo.stroke);
			// Fill
			setAttr(p[i], "fill", colourinfo.fill);
		}
	}
}

function setup_onclick_handlers() {
	if (svg && constraints) {
		Object.keys(constraints.v2c).map(function(v) {
			var elem = svg.getElementById(v);
			// Add a onclick handler for the svgelements
			elem.onclick = function() {
				var id = elem.getAttribute("id");
				showConstraintsForNode(id);}
		});
		document.getElementById('allconstraintsbtn').onclick =
			function() {
				showConstraints(constraints.constraints.map((_, idx) => idx));
			};
	}
}

function init(json, svgid, svgcss) {
	// Wait until svgelement was loaded
	document.getElementById(svgid).addEventListener('load', function(o) {
		var svgdoc = o.currentTarget.contentDocument;
		add_svg_stylesheet(svgdoc, svgcss);
		svg = svgdoc.getElementsByTagName("svg")[0];
		setup_onclick_handlers();
	}, false);

	var svgdoc = resolve(svgid);

	loadJSON(json, function(c) {
		constraints = c;
		setup_onclick_handlers();
	});
}
