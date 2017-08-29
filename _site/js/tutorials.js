function show(id) {
  var elements = document.getElementsByClassName('showhide');
  for (var i = 0; i < elements.length; i++)
      elements[i].style.display = 'none';

  document.getElementById(id).style.display='block';
}
