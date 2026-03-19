function togglePwd(id, btn) {
  var input = document.getElementById(id);
  if (input.type === "password") {
    input.type = "text";
    btn.textContent = "Dölj";
  } else {
    input.type = "password";
    btn.textContent = "Visa";
  }
}