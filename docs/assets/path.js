/* Shared behavior for the per-tier step pages: copy buttons + toast,
   and (Tier 1) wiring the live-dashboard button from ?dash=<companion url>. */
(function(){
  // copy-to-clipboard on every .cmd's button
  document.querySelectorAll('.copy').forEach(function(b){
    b.addEventListener('click',function(){
      var t=b.getAttribute('data-copy');
      navigator.clipboard.writeText(t).then(function(){
        b.textContent='copied';
        var toast=document.getElementById('toast');
        if(toast){
          toast.textContent='Copied: '+(t.length>40?t.slice(0,40)+'…':t);
          toast.classList.add('show');
          setTimeout(function(){toast.classList.remove('show')},1300);
        }
        setTimeout(function(){b.textContent='copy'},1200);
      });
    });
  });

  // Tier 1: if the presenter shared a dashboard via ?dash=<url>, light up the button.
  // Only accept http(s) so a crafted ?dash=javascript:... can't run.
  var btn=document.getElementById('runlive-btn');
  if(btn){
    var wait=document.getElementById('runlive-wait');
    var dash='';
    try{ dash=new URLSearchParams(location.search).get('dash')||''; }catch(e){}
    if(dash&&/^https?:\/\//i.test(dash)){
      btn.href=dash; btn.style.display='inline-block';
      if(wait) wait.style.display='none';
    }
  }
})();
