
let selector = document.getElementById('sw_selector');
let updateDisplay = function(mediaList) {
    let postDivs = document.getElementsByClassName('sw_post');
    let medias = null;
    if (mediaList != null)
      medias = mediaList.split(',');
    let nb = 0;
    for (let postDiv of postDivs) {
        let found = false;
        if (medias == null) {
          found = true;
        } else {
          for (let media of medias) {
              if (postDiv.classList.contains(media + '_post')) {
                  found = true;
                  break;
              }
          }
        }
        if (found && nb < maxPosts) {
            postDiv.style.display = 'inline-block';
            nb++;
        } else
            postDiv.style.display = 'none';
    }
};
if (selector != null) {
    updateDisplay(selector.value);
    selector.addEventListener('change', function(e) {
        updateDisplay(selector.value);
    }, false);
} else {
  updateDisplay(null);
}
