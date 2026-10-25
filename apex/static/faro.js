/* FARO · utilidades de interfaz (namespace window.faro) */
(function (apex, $) {
  "use strict";
  var faro = window.faro = window.faro || {};

  /* Atajos de teclado en la revisión de menciones (página 21).
     Alt+V validar · Alt+G guardar corrección · Alt+D descartar.
     Sólo se activan si el botón existe y está visible (permisos). */
  faro.atajosRevision = function () {
    document.addEventListener("keydown", function (e) {
      if (!e.altKey) { return; }
      var mapa = { v: "VALIDAR", g: "GUARDAR", d: "DESCARTAR" };
      var req = mapa[(e.key || "").toLowerCase()];
      var btn = req && document.getElementById(req.toLowerCase());
      if (btn && btn.offsetParent !== null) {
        e.preventDefault();
        btn.click();
      }
    });
  };

  /* Asistente: Ctrl/Cmd+Enter envía la pregunta; se desplaza al último mensaje. */
  faro.asistente = function () {
    var area = document.getElementById("P14_PREGUNTA");
    if (area) {
      area.addEventListener("keydown", function (e) {
        if ((e.ctrlKey || e.metaKey) && e.key === "Enter" && area.value.trim()) {
          e.preventDefault();
          apex.page.submit({ request: "PREGUNTAR", showWait: true });
        }
      });
      area.focus();
    }
    var ultimo = document.querySelector(".faro-chat .t-Comments-item:last-child");
    if (ultimo) { ultimo.scrollIntoView({ block: "end" }); }
    $(document).on("click", ".faro-sugerencia", function () {
      apex.item("P14_PREGUNTA").setValue(this.getAttribute("data-pregunta"));
      apex.page.submit({ request: "PREGUNTAR", showWait: true });
    });
  };

  /* Selección múltiple en bandejas: devuelve ids marcados separados por ":" */
  faro.seleccion = function (selector) {
    return $(selector || "input[name=f01]:checked").map(function () { return this.value; }).get().join(":");
  };
  faro.marcarTodos = function (origen) {
    $("input[name=f01]").prop("checked", origen.checked);
  };
})(apex, apex.jQuery);
