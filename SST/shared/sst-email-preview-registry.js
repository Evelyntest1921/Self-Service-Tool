(function (global) {
  function escapeHtml(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function textToHtml(value) {
    return escapeHtml(value).replace(/\r\n|\r|\n/g, "<br>");
  }

  var defaultSignature =
    "<p style=\"margin:20px 0 0;font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:20px;color:#161616;\">Best regards,<br><span style=\"font-style:italic;font-family:serif;font-size:20px;\">MagMutual</span><br>MagMutual Insurance</p>";

  global.SSTEmailPreviewRegistry = {
    quick_send: {
      fieldIds: ["step2Preheader", "step2Body"],
      render: function (state) {
        var greeting = escapeHtml(state.greeting || "Hello,");
        var introBody = textToHtml(state.body || "");
        var signatureHtml = state.signatureHtml || defaultSignature;
        return [
          "<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" style=\"background:#ffffff;margin:0;padding:30px 0;\">",
          "<tr><td align=\"left\">",
          "<table role=\"presentation\" width=\"600\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" style=\"background:#ffffff;max-width:100%;\">",
          "<tr><td style=\"font-family:Arial,Helvetica,sans-serif;color:#161616;font-size:14px;line-height:20px;padding:0 20px;\">",
          "<p style=\"margin:0 0 18px;\">" + greeting + "</p>",
          "<p style=\"margin:0 0 18px;\">" + introBody + "</p>",
          signatureHtml,
          "</td></tr>",
          "</table>",
          "</td></tr>",
          "</table>"
        ].join("");
      }
    },
    bg_header: {
      fieldIds: ["step2Preheader", "step2Headline", "step2BodyBg", "step2SurveyId"],
      render: function (state) {
        var headline = escapeHtml(state.headline || state.subject || "Your headline");
        var greeting = escapeHtml(state.greeting || "Hello,");
        var textBody = textToHtml(state.body || "");
        var signatureHtml = state.signatureHtml || defaultSignature;
        var templateName = String(state.templateEmailName || "").toLowerCase().trim();
        var surveyBlock = "";
        if (templateName === "survey") {
          var surveyId = encodeURIComponent(state.surveyId || "SURV_20260612_102301");
          var surveyUrl =
            "https://cloud.go.magmutual.com/MH1Fdf3gkpiWmvpt?id=" +
            surveyId +
            "&contact=" +
            encodeURIComponent(state.contactId || "");
          surveyBlock =
            "<table role=\"presentation\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\"><tr><td bgcolor=\"#0060F5\" style=\"background:#0060F5;\"><a href=\"" +
            surveyUrl +
            "\" target=\"_blank\" style=\"display:block;padding:10px 99px 10px 10px;color:#ffffff;font-family:Arial,Helvetica,sans-serif;font-size:16px;text-decoration:none;\">Take Survey</a></td></tr></table>";
        }
        return [
          "<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" style=\"background:#eaeaea;margin:0;padding:0;\">",
          "<tr><td align=\"center\">",
          "<table role=\"presentation\" width=\"600\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" style=\"background:#393939;max-width:100%;\">",
          "<tr><td style=\"padding:30px;\"><img src=\"https://image.go.magmutual.com/lib/fe2f11747364047d731d72/m/1/MM_PrimaryLogo_Reversed.png\" alt=\"MagMutual\" width=\"200\" border=\"0\" style=\"display:block;\"></td></tr>",
          "<tr><td style=\"padding:20px 45px 50px;font-family:Arial,Helvetica,sans-serif;color:#ffffff;\"><p style=\"font-size:32px;line-height:36px;margin:0;color:#ffffff;\">" +
            headline +
            "</p></td></tr>",
          "</table>",
          "<table role=\"presentation\" width=\"600\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" style=\"background:#ffffff;max-width:100%;\">",
          "<tr><td style=\"padding:20px 45px 50px;font-family:Arial,Helvetica,sans-serif;color:#161616;font-size:14px;line-height:20px;\">",
          "<p style=\"margin:0 0 20px;\">" + greeting + "</p>",
          "<p style=\"margin:0 0 20px;\">" + textBody + "</p>",
          surveyBlock,
          signatureHtml,
          "</td></tr>",
          "</table>",
          "</td></tr>",
          "</table>"
        ].join("");
      }
    }
  };

  global.SSTEmailPreview = {
    getRenderer: function (key) {
      return global.SSTEmailPreviewRegistry[key] || global.SSTEmailPreviewRegistry.quick_send;
    },
    readState: function (formRoot) {
      var root = formRoot || document;
      function val(id) {
        var node = root.getElementById ? root.getElementById(id) : document.getElementById(id);
        return node ? node.value : "";
      }
      var rendererKey = val("step2PreviewRenderer") || "quick_send";
      var bodyVal =
        rendererKey === "bg_header" ? val("step2BodyBg") : val("step2Body");
      return {
        itemBaseName: val("step2ItemBaseName"),
        subject: val("step2EmailSubjectLine"),
        preheader: val("step2Preheader"),
        body: bodyVal,
        headline: val("step2Headline"),
        surveyId: val("step2SurveyId"),
        templateEmailName: val("step2TemplateEmailName"),
        greeting: "Hello,",
        signatureHtml: defaultSignature
      };
    },
    update: function (rendererKey, state, ui) {
      var renderer = global.SSTEmailPreview.getRenderer(rendererKey);
      if (ui.subjectEl) {
        ui.subjectEl.textContent = state.subject || "Email subject";
      }
      if (ui.preheaderEl) {
        ui.preheaderEl.textContent = state.preheader || "";
      }
      if (ui.dateEl) {
        ui.dateEl.textContent = new Date().toLocaleDateString("en-US", {
          month: "short",
          day: "numeric"
        });
      }
      if (ui.frameEl) {
        ui.frameEl.srcdoc = renderer.render(state);
      }
    },
    toggleRendererFields: function (rendererKey) {
      var panels = document.querySelectorAll("[data-renderer-fields]");
      panels.forEach(function (panel) {
        var match = panel.getAttribute("data-renderer-fields") === rendererKey;
        panel.style.display = match ? "block" : "none";
      });
    }
  };
})(typeof window !== "undefined" ? window : this);
