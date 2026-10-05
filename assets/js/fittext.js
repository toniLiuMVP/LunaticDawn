/* 自動縮放 .raw-text 字型：
   - 找最寬的「表格行」（含 Box Drawing ─│ 或 3+空格 或 3+全形空格的行）
   - 按比例縮小字型讓表格行完整顯示不換行
   - 段落行（無對齊格式）由 CSS pre-wrap 自然換行 */
(function(){
  var timer;
  var tableRe=/[\u2500-\u257F]|   |\t|\u3000.*\u3000.*\u3000/;
  function fit(){
    var els=document.querySelectorAll('.raw-text');
    for(var i=0;i<els.length;i++){
      var el=els[i];
      el.style.fontSize='';
      var lines=el.textContent.split('\n');
      var target='';
      for(var j=0;j<lines.length;j++){
        if(tableRe.test(lines[j])&&lines[j].length>target.length) target=lines[j];
      }
      if(!target) continue;
      var ruler=document.createElement('span');
      ruler.style.cssText='position:absolute;visibility:hidden;white-space:pre;font:inherit;';
      ruler.textContent=target;
      el.appendChild(ruler);
      var lineW=ruler.offsetWidth;
      ruler.remove();
      var cs=getComputedStyle(el);
      var maxFS=parseFloat(cs.fontSize);
      var padL=parseFloat(cs.paddingLeft),padR=parseFloat(cs.paddingRight);
      var availW=el.clientWidth-padL-padR;
      if(lineW<=availW) continue;
      var fs=Math.floor(maxFS*availW/lineW*2)/2;
      if(fs<8) fs=8;
      el.style.fontSize=fs+'px';
    }
  }
  window.addEventListener('load',fit);
  window.addEventListener('resize',function(){clearTimeout(timer);timer=setTimeout(fit,150);});
})();
